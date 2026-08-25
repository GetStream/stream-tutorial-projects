#if os(iOS)
// StreamBotEngine.swift
// The runtime that makes a teammate act like one: it plans, it works the plan in
// the open, it stops at the approval gate, and it remembers.
//
// The shape of a handoff
// ----------------------
// One user message produces two bot messages, both authored by the bot itself so
// they arrive as incoming messages in the thread:
//
//   1. A run card — a `StreamBotRun` in `extraData`. Edited as steps tick over, so
//      the plan the user is watching is the same object the runtime is walking.
//   2. A prose reply — the actual draft, digest or write-up, streamed in.
//
// Why the plan is a separate message rather than text inside the reply: the card
// has to stay interactive after the reply is finished. Approve and Reject live
// on it, and the user may come back to a parked run hours later.
//
// What these bots can and cannot do
// ---------------------------------
// The real Grok Bot drives a browser on its own computer. StreamBot runs
// entirely on-device with no network tools at all, so the model is instructed to
// do the part it can genuinely do — reason, draft, structure, summarise — and to
// state plainly what it would need rather than narrating a login it never
// performed. That constraint is in the system prompt, not in a disclaimer, so a
// step reads "Draft the reply, flag the two facts I need from you" instead of
// "Signed in to the vendor portal".
//
// Cost of talking to a small model
// --------------------------------
// A run is planning + one call per step + one synthesis. Steps are capped at
// four and step notes at 48 tokens, because the whole point is that the user
// watches it happen; a plan with nine steps on a 1 B model is a progress bar
// with extra words.

import Foundation
import FoundationModels
import Observation
import StreamChat
import SwiftUI

// MARK: - Plan schema

/// Guided-generation shape for the planning call. Description-only guides: the
/// counts are expressed in prose because that is what the small models in this
/// app follow reliably.
@Generable
struct StreamBotPlanSchema {
    @Guide(description: "A four to seven word title for this piece of work. No quotes, no trailing period.")
    var title: String

    @Guide(description: "Two to four steps, each a short imperative phrase starting with a verb. Concrete, not generic project-management filler.")
    var steps: [String]
}

/// Guided-generation shape for the routine distillation.
@Generable
struct StreamBotRoutineSchema {
    @Guide(description: "A three to six word name for this workflow.")
    var name: String

    @Guide(description: "One sentence describing when this workflow should be used again, in the user's own vocabulary.")
    var trigger: String

    @Guide(description: "The ordered steps to repeat next time, each a short imperative phrase.")
    var steps: [String]
}

/// Guided-generation shape for what the bot learned about the user.
@Generable
struct StreamBotMemorySchema {
    @Guide(description: "Standing preferences the user revealed about how they want work done. Empty when the message revealed none.")
    var preferences: [String]

    @Guide(description: "Durable facts about the user's world — teams, tools, accounts, names. Empty when none.")
    var facts: [String]
}

// MARK: - Engine

@MainActor
@Observable
final class StreamBotEngine {
    static let shared = StreamBotEngine()

    enum Phase: Equatable {
        case idle
        case planning
        /// Working a named step, so the composer can say which one.
        case working(String)
        case replying
        /// Finished, parked on the approval gate.
        case awaitingApproval
        case failed(String)

        var isBusy: Bool {
            switch self {
            case .planning, .working, .replying: true
            default: false
            }
        }

        var label: String? {
            switch self {
            case .idle: nil
            case .planning: "Planning"
            case .working(let step): step
            case .replying: "Writing"
            case .awaitingApproval: "Waiting for you"
            case .failed(let message): message
            }
        }

        /// For places with room for a few words and no room for a paragraph — a
        /// roster tile, a header. The full explanation belongs where the user can
        /// act on it: the run card and the strip above the composer.
        var shortLabel: String? {
            switch self {
            case .failed: "Didn't finish"
            default: label
            }
        }
    }

    /// Phase per channel, keyed by `cid.rawValue`. Per channel rather than
    /// global because the Ops Room and a one-to-one thread can be working at the
    /// same time and each header shows only its own state.
    private(set) var phases: [String: Phase] = [:]

    private var tasks: [String: Task<Void, Never>] = [:]

    private init() {}

    func phase(in cid: ChannelId) -> Phase {
        phases[cid.rawValue] ?? .idle
    }

    func isBusy(in cid: ChannelId) -> Bool {
        phase(in: cid).isBusy
    }

    var waitingBots: [StreamBotTeammate] {
        StreamBotRoster.shared.bots.filter { phase(in: $0.threadChannelId) == .awaitingApproval }
    }

    var workingBots: [StreamBotTeammate] {
        StreamBotRoster.shared.bots.filter { phase(in: $0.threadChannelId).isBusy }
    }

    /// Drops in-flight work and the loaded model session. The analog of Grok
    /// Bot's "Reconnect computer" — on this phone that means a fresh session.
    func reconnectRuntime() {
        let keys = Array(tasks.keys)
        for cid in keys {
            tasks[cid]?.cancel()
            tasks[cid] = nil
            if let channelId = try? ChannelId(cid: cid) {
                setPhase(.idle, in: channelId)
            } else {
                phases[cid] = .idle
            }
        }
    }

    // MARK: Entry points

    /// Handles a message the user just sent to `bot`.
    func start(
        request: String,
        userMessageId: MessageId?,
        bot: StreamBotTeammate,
        in cid: ChannelId
    ) {
        let trimmed = request.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard StreamBotSender.shared.canSpeak(botId: bot.id) else {
            setPhase(.failed("\(bot.shortName) has no access token in this build and cannot reply."), in: cid)
            return
        }
        guard !isBusy(in: cid) else { return }

        // Marked busy here, synchronously, rather than inside the task. `run`
        // awaits the acknowledgement and typing events before it sets a phase, so
        // a second trigger arriving in the same turn — the socket echoing a
        // message the SDK already delivered locally — would sail past the guard
        // above and the thread would get two cards for one request.
        setPhase(.planning, in: cid)

        tasks[cid.rawValue]?.cancel()
        tasks[cid.rawValue] = Task { [weak self] in
            await self?.run(request: trimmed, userMessageId: userMessageId, bot: bot, in: cid)
        }
    }

    /// Handles a message in a room that was not addressed to anyone.
    ///
    /// The lead reads it, picks whoever owns that kind of work, says so in the
    /// thread, and that teammate takes it from there. The handoff is posted as a
    /// message rather than done silently because in a room the user's next
    /// question is always "who has this?" — and because it is the point at which
    /// they can tell the lead it chose wrong.
    func route(
        request: String,
        userMessageId: MessageId?,
        lead: StreamBotTeammate,
        candidates: [StreamBotTeammate],
        in cid: ChannelId
    ) {
        let trimmed = request.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isBusy(in: cid) else { return }

        // With nobody to hand to, the lead does the work itself.
        guard !candidates.isEmpty else {
            start(request: trimmed, userMessageId: userMessageId, bot: lead, in: cid)
            return
        }

        setPhase(.planning, in: cid)
        tasks[cid.rawValue]?.cancel()
        tasks[cid.rawValue] = Task { [weak self] in
            guard let self else { return }
            let chosen = await Self.pick(from: candidates, for: trimmed, lead: lead)

            if StreamBotSender.shared.canSpeak(botId: lead.id) {
                _ = try? await StreamBotSender.shared.send(
                    botId: lead.id,
                    in: cid,
                    text: "\(chosen.shortName) has this — \(chosen.lane.title.lowercased()) is theirs.",
                    extraData: StreamBotMessagePayload.handoff(from: lead.id, to: chosen.id)
                )
            }

            tasks[cid.rawValue] = nil
            setPhase(.idle, in: cid)
            start(request: trimmed, userMessageId: userMessageId, bot: chosen, in: cid)
        }
    }

    /// Stops the current run and leaves the card marked interrupted, so the
    /// thread never shows a plan that is silently no longer being worked.
    func cancel(in cid: ChannelId) {
        tasks[cid.rawValue]?.cancel()
        tasks[cid.rawValue] = nil
        setPhase(.idle, in: cid)
    }

    // MARK: The run

    private func run(
        request: String,
        userMessageId: MessageId?,
        bot: StreamBotTeammate,
        in cid: ChannelId
    ) async {
        let store = StreamBotStore.shared
        let sender = StreamBotSender.shared

        // Acknowledge before the model has warmed up. On a cold zoo bundle the
        // first token can be twenty seconds out, and an unanswered message for
        // twenty seconds reads as a dropped one.
        if let userMessageId {
            await sender.acknowledge(botId: bot.id, messageId: userMessageId, in: cid)
        }
        await sender.startTyping(botId: bot.id, in: cid)

        // A learned routine replaces the planning call outright: the user
        // already taught these steps, so re-deriving them would be both slower
        // and worse than what they demonstrated.
        let routine = store.routine(matching: request, for: bot.id)

        var run = StreamBotRun(
            botId: bot.id,
            request: request,
            title: routine?.name ?? Self.provisionalTitle(from: request),
            steps: routine.map { $0.steps.map { StreamBotRunStep(title: $0) } } ?? [],
            status: .planning,
            routineId: routine?.id
        )

        setPhase(.planning, in: cid)

        // Post the card immediately so the plan appears while the model thinks.
        let cardId: MessageId
        do {
            cardId = try await sender.send(
                botId: bot.id,
                in: cid,
                text: run.title,
                extraData: run.messageExtraData(isStreaming: true)
            )
        } catch {
            setPhase(.failed(error.localizedDescription), in: cid)
            await sender.stopTyping(botId: bot.id, in: cid)
            return
        }

        let choice = AIModelPreferences.shared.textModel

        // What this teammate has been given. Plugins add two different things: the
        // skill that matches this request goes into the instructions, and the
        // connectors become tools the model can call while it works.
        let plugins = StreamBotPluginStore.shared
        let skill = Self.skill(matching: request, from: plugins.skills(for: bot.id))
        let tools = choice.supportsToolCalling
            ? StreamBotPluginToolbox.tools(for: plugins.connectors(for: bot.id))
            : []
        _ = StreamBotToolLog.shared.drain()

        do {
            // Two sessions over the same loaded model, because a transcript is a
            // habit. After a guided call the transcript holds a JSON reply, and a
            // small model asked for prose in that same session will hand back
            // another one — the user sees `{"title": …}` in the thread. Planning
            // and learning get one transcript, the writing gets its own.
            //
            // Only the writer gets the tools. Planning is deciding what to do;
            // reading the calendar to decide it would pay for a tool call before
            // the plan exists, and the step that needs the data is the one that
            // should fetch it.
            let planner = try await CoreAITextSessionProvider.shared.makeSession(
                for: choice,
                instructions: Self.instructions(
                    for: bot,
                    routine: routine,
                    store: store,
                    voice: .structured,
                    connectors: tools.isEmpty ? [] : plugins.connectors(for: bot.id),
                    skill: skill
                )
            )
            let writer = try await CoreAITextSessionProvider.shared.makeSession(
                for: choice,
                instructions: Self.instructions(
                    for: bot,
                    routine: routine,
                    store: store,
                    voice: .prose,
                    connectors: tools.isEmpty ? [] : plugins.connectors(for: bot.id),
                    skill: skill
                ),
                tools: tools
            )

            // 1. Plan, unless a routine already supplied one.
            if run.steps.isEmpty {
                let plan = try await Self.plan(request: request, bot: bot, using: planner, choice: choice)
                run.title = plan.title.isEmpty ? run.title : plan.title
                run.steps = plan.steps.prefix(4).map { StreamBotRunStep(title: $0) }
            }
            if run.steps.isEmpty {
                run.steps = [StreamBotRunStep(title: "Work the request")]
            }
            run.status = .working
            run.touch()
            await update(run, cardId: cardId, bot: bot, in: cid, isStreaming: true)

            // 2. Work each step. Notes accumulate into the context the synthesis
            //    call reads, so the final answer is built out of the steps rather
            //    than being a second, unrelated pass over the request.
            var findings: [String] = []
            for index in run.steps.indices {
                try Task.checkCancellation()
                run.steps[index].status = .active
                run.touch()
                setPhase(.working(run.steps[index].title), in: cid)
                await update(run, cardId: cardId, bot: bot, in: cid, isStreaming: true)
                await sender.startTyping(botId: bot.id, in: cid)

                let note = try await Self.workStep(
                    run.steps[index].title,
                    request: request,
                    soFar: findings,
                    using: writer
                )
                run.steps[index].status = .done
                run.steps[index].note = note
                // Credit the plugin if the model reached for one. A tool call
                // happens inside the generation, invisibly; the run card exists so
                // that the user can see where the work went, so the step says which
                // surface it really touched rather than which one was planned.
                if let surface = StreamBotToolLog.shared.drain().compactMap(\.surface).first {
                    run.steps[index].workspace = surface
                }
                run.touch()
                findings.append("\(run.steps[index].title): \(note)")
                await update(run, cardId: cardId, bot: bot, in: cid, isStreaming: true)
            }

            // 3. Stream the deliverable as its own message.
            try Task.checkCancellation()
            setPhase(.replying, in: cid)
            let result = try await stream(
                prompt: Self.synthesisPrompt(request: request, findings: findings, bot: bot),
                bot: bot,
                in: cid,
                using: writer
            )
            run.result = result

            // 4. The approval gate. Enforced here, from the bot's policy — not
            //    asked of the model, which could be talked out of it.
            run.status = bot.approval.requiresApproval ? .awaitingApproval : .done
            run.touch()
            await update(run, cardId: cardId, bot: bot, in: cid, isStreaming: false)
            setPhase(run.status == .awaitingApproval ? .awaitingApproval : .idle, in: cid)
            if run.status == .awaitingApproval {
                StreamBotNotifications.notifyApproval(bot: bot, title: run.title)
            } else {
                StreamBotNotifications.notifyFinished(bot: bot, title: run.title)
            }

            if let routineId = run.routineId {
                store.markRoutineRun(routineId)
            }

            // 5. Learn from the exchange. Last on purpose: it is the only part
            //    the user is not waiting on, and a failure here must not mark an
            //    otherwise good run as failed.
            await Self.learn(from: request, bot: bot, using: planner, store: store)
        } catch is CancellationError {
            run.status = .interrupted
            run.note = "Stopped before finishing."
            run.touch()
            await update(run, cardId: cardId, bot: bot, in: cid, isStreaming: false)
            setPhase(.idle, in: cid)
        } catch {
            let explained = Self.explain(error)
            run.status = .failed
            run.note = explained
            run.touch()
            await update(run, cardId: cardId, bot: bot, in: cid, isStreaming: false)
            setPhase(.failed(explained), in: cid)
            StreamBotNotifications.notifyFailed(bot: bot, message: explained)
        }

        await sender.stopTyping(botId: bot.id, in: cid)
        tasks[cid.rawValue] = nil
    }

    /// Turns a failure into something the user can act on.
    ///
    /// The two frameworks behind a run both describe their failures to a
    /// developer rather than to whoever is holding the phone. FoundationModels
    /// reports a failed inference as `error -1`, and StreamChat names the
    /// internal type that refused a write. Neither tells the user what to do, so
    /// this says what to do and drops the rest.
    private static func explain(_ error: Error) -> String {
        if error is StreamBotError { return error.localizedDescription }

        if (error as NSError).domain.hasPrefix("FoundationModels") {
            #if targetEnvironment(simulator)
            return "Apple's on-device model can't run in the Simulator. Pick a Core AI model in Models, or run on a device with Apple Intelligence."
            #else
            return "The on-device model couldn't finish this one. Check Apple Intelligence is switched on, or pick a Core AI model in Models."
            #endif
        }

        if error is ClientError {
            return "Lost the connection to the thread while writing this. Try again."
        }

        return error.localizedDescription
    }

    // MARK: Approval

    func approve(_ run: StreamBotRun, messageId: MessageId, bot: StreamBotTeammate, in cid: ChannelId) {
        var approved = run
        approved.status = .approved
        approved.touch()
        commit(approved, messageId: messageId, bot: bot, in: cid)
        setPhase(.idle, in: cid)
        StreamBotHaptics.success()
    }

    func reject(_ run: StreamBotRun, reason: String?, messageId: MessageId, bot: StreamBotTeammate, in cid: ChannelId) {
        var rejected = run
        rejected.status = .rejected
        rejected.note = reason
        rejected.touch()
        commit(rejected, messageId: messageId, bot: bot, in: cid)
        setPhase(.idle, in: cid)
        StreamBotHaptics.warning()

        // A rejection is the most valuable thing the user ever tells a bot, so
        // it is stored as a correction even when they gave no reason.
        if let reason, !reason.trimmingCharacters(in: .whitespaces).isEmpty {
            StreamBotStore.shared.remember(
                StreamBotMemory(botId: bot.id, kind: .correction, text: reason)
            )
        }
    }

    /// Re-runs a failed or rejected run from its original brief.
    func retry(_ run: StreamBotRun, bot: StreamBotTeammate, in cid: ChannelId) {
        start(request: run.request, userMessageId: nil, bot: bot, in: cid)
    }

    private func commit(_ run: StreamBotRun, messageId: MessageId, bot: StreamBotTeammate, in cid: ChannelId) {
        Task {
            try? await StreamBotSender.shared.edit(
                botId: bot.id,
                messageId: messageId,
                in: cid,
                text: run.title,
                extraData: run.messageExtraData(isStreaming: false)
            )
        }
    }

    // MARK: Teaching

    /// Distils the thread the user just worked through into a reusable routine.
    ///
    /// This is the "show a Bot how it's done" path: the user does the work in
    /// the open, then taps Teach, and the model reads back the real conversation
    /// rather than asking them to write a procedure.
    func teachRoutine(
        from messages: [StreamChatMessage],
        bot: StreamBotTeammate,
        in cid: ChannelId
    ) async throws -> StreamBotRoutine {
        let transcript = messages
            .reversed()
            .prefix(40)
            .map { "\($0.author.id == StreamBotCredentials.userId ? "User" : bot.shortName): \($0.text)" }
            .joined(separator: "\n")
        guard transcript.count > 40 else {
            throw StreamBotError("There is not enough in this thread yet to learn a routine from.")
        }

        let choice = AIModelPreferences.shared.textModel
        let session = try await CoreAITextSessionProvider.shared.makeSession(
            for: choice,
            instructions: """
                You turn a worked example into a repeatable routine.
                Read the conversation and write down the procedure that was \
                actually followed, in the order it happened. Keep the user's \
                own vocabulary. Do not invent steps nobody took.
                """
        )

        let prompt = "Conversation:\n\(transcript)"
        let routine: StreamBotRoutine
        if choice.supportsGuidedGeneration {
            let schema = try await session.respond(
                to: prompt,
                generating: StreamBotRoutineSchema.self
            ).content
            routine = StreamBotRoutine(
                botId: bot.id,
                name: schema.name,
                trigger: schema.trigger,
                steps: schema.steps.filter { !$0.isBlankLine }
            )
        } else {
            let text = try await session.respond(
                to: prompt + "\n\n" + Self.routineFormat,
                options: GenerationOptions(maximumResponseTokens: 220)
            ).content
            let parsed = Self.parseRoutine(text)
            routine = StreamBotRoutine(
                botId: bot.id,
                name: parsed.name,
                trigger: parsed.trigger,
                steps: parsed.steps
            )
        }

        guard !routine.steps.isEmpty else {
            throw StreamBotError("\(bot.shortName) could not make out a repeatable procedure here.")
        }
        StreamBotStore.shared.add(routine)

        // Post the confirmation as the bot, so learning is visible in the thread
        // it was learned from rather than only in a settings screen.
        if StreamBotSender.shared.canSpeak(botId: bot.id) {
            let body = ([routine.name] + routine.steps.map { "• \($0)" }).joined(separator: "\n")
            _ = try? await StreamBotSender.shared.send(
                botId: bot.id,
                in: cid,
                text: "Learned this routine:\n\(body)",
                extraData: StreamBotMessagePayload.routine(
                    botId: bot.id,
                    routineId: routine.id,
                    name: routine.name
                )
            )
        }
        return routine
    }

    // MARK: Streaming a reply

    /// Streams a prose answer into a new bot message.
    ///
    /// The message is created once and then edited, which is what makes tokens
    /// appear in the thread instead of arriving as a wall. Edits are throttled:
    /// a token-per-edit stream would issue hundreds of writes for one paragraph,
    /// and Stream rate-limits long before the model runs out of tokens.
    private func stream(
        prompt: String,
        bot: StreamBotTeammate,
        in cid: ChannelId,
        using session: LanguageModelSession
    ) async throws -> String {
        let sender = StreamBotSender.shared
        var messageId: MessageId?
        var latest = ""
        var lastPushed = ""
        var lastPushAt = Date.distantPast

        let responses = session.streamResponse(
            to: prompt,
            options: GenerationOptions(maximumResponseTokens: 420)
        )

        for try await snapshot in responses {
            try Task.checkCancellation()
            latest = Self.prose(snapshot.content)
            guard !latest.isEmpty else { continue }

            let elapsed = Date().timeIntervalSince(lastPushAt)
            let grew = latest.count - lastPushed.count
            guard elapsed > Self.editInterval || grew > Self.editCharacters else { continue }

            if let messageId {
                try? await sender.edit(
                    botId: bot.id,
                    messageId: messageId,
                    in: cid,
                    text: latest,
                    extraData: StreamBotMessagePayload.reply(botId: bot.id, isStreaming: true)
                )
            } else {
                messageId = try await sender.send(
                    botId: bot.id,
                    in: cid,
                    text: latest,
                    extraData: StreamBotMessagePayload.reply(botId: bot.id, isStreaming: true)
                )
            }
            lastPushed = latest
            lastPushAt = Date()
        }

        guard !latest.isEmpty else {
            throw StreamBotError("\(bot.shortName) did not produce anything for this one.")
        }

        // Final write always goes out, throttle or not, and clears the caret
        // flag. Best-effort: the reply is already in the thread by this point, so
        // a dropped write costs a caret, not the answer.
        if let messageId {
            try? await sender.edit(
                botId: bot.id,
                messageId: messageId,
                in: cid,
                text: latest,
                extraData: StreamBotMessagePayload.reply(botId: bot.id, isStreaming: false)
            )
        } else {
            _ = try await sender.send(
                botId: bot.id,
                in: cid,
                text: latest,
                extraData: StreamBotMessagePayload.reply(botId: bot.id, isStreaming: false)
            )
        }
        return latest
    }

    private static let editInterval: TimeInterval = 0.45
    private static let editCharacters = 90

    // MARK: Card updates

    /// Pushes the card's current state into the thread.
    ///
    /// Deliberately cannot fail the run. Redrawing the card is bookkeeping: the
    /// work either succeeded or it did not, and a chat write that did not land
    /// says nothing about which. Reporting one as a failed run is how a finished
    /// piece of work ends up wearing a networking error.
    private func update(
        _ run: StreamBotRun,
        cardId: MessageId,
        bot: StreamBotTeammate,
        in cid: ChannelId,
        isStreaming: Bool
    ) async {
        do {
            try await StreamBotSender.shared.edit(
                botId: bot.id,
                messageId: cardId,
                in: cid,
                text: run.title,
                extraData: run.messageExtraData(isStreaming: isStreaming)
            )
        } catch {
            // Mid-run writes can be dropped without harm — another one is a
            // second away. The last write is the card's final state, and a card
            // left saying "Planning" after the run is over is worse than a slow
            // one, so it gets a second attempt.
            guard !isStreaming else { return }
            try? await Task.sleep(for: .milliseconds(700))
            try? await StreamBotSender.shared.edit(
                botId: bot.id,
                messageId: cardId,
                in: cid,
                text: run.title,
                extraData: run.messageExtraData(isStreaming: false)
            )
        }
    }

    private func setPhase(_ phase: Phase, in cid: ChannelId) {
        phases[cid.rawValue] = phase
        StreamBotHaptics.phaseChanged(phase)
    }
}

// MARK: - Model calls

private extension StreamBotEngine {
    /// Turns the request into a titled plan.
    static func plan(
        request: String,
        bot: StreamBotTeammate,
        using session: LanguageModelSession,
        choice: ChatModelChoice
    ) async throws -> (title: String, steps: [String]) {
        let prompt = """
            Request from the user:
            \(request)

            Lay out how you will handle it. Use \(bot.lane.stepVocabulary)-style \
            steps that fit this request specifically.
            """

        if choice.supportsGuidedGeneration {
            let schema = try await session.respond(
                to: prompt,
                generating: StreamBotPlanSchema.self
            ).content
            return (
                schema.title.trimmingCharacters(in: .whitespacesAndNewlines),
                schema.steps.filter { !$0.isBlankLine }
            )
        }

        let text = try await session.respond(
            to: prompt + "\n\n" + planFormat,
            options: GenerationOptions(maximumResponseTokens: 180)
        ).content
        return parsePlan(text)
    }

    /// Works one step and reports what came of it.
    static func workStep(
        _ step: String,
        request: String,
        soFar: [String],
        using session: LanguageModelSession
    ) async throws -> String {
        var prompt = "The request: \(request)\n"
        if !soFar.isEmpty {
            prompt += "\nAlready done:\n" + soFar.joined(separator: "\n")
        }
        prompt += """


            Current step: \(step)

            If a tool can answer this step — the calendar, reminders, contacts, \
            threads, or the date — call it first, then report what it returned. \
            Do not claim the calendar is empty without having called readCalendar. \
            Be concrete. If the step needs information you do not have, say \
            exactly what is missing instead of inventing it.
            """
        let response = try await session.respond(
            to: prompt,
            options: GenerationOptions(maximumResponseTokens: 220)
        ).content
        return prose(response)
    }

    /// Prose, even when the model answered with a structure.
    ///
    /// Separate sessions make a JSON answer to a prose question rare; this makes
    /// it harmless. Quoted values are pulled out in the order they appear, which
    /// also works on the half-written JSON of a stream still in progress — so
    /// the user reads a sentence forming rather than watching braces arrive.
    static func prose(_ text: String) -> String {
        let cleaned = CoreAITextSessionProvider.cleaned(text)
        guard cleaned.hasPrefix("{") || cleaned.hasPrefix("[") else { return cleaned }

        var values: [String] = []
        var current = ""
        var isReadingKey = true
        var isInString = false
        var isEscaped = false
        /// Inside a list, a comma separates values rather than starting a new key.
        var arrayDepth = 0

        for character in cleaned {
            if isEscaped {
                current.append(character == "n" ? "\n" : character)
                isEscaped = false
            } else if isInString, character == "\\" {
                isEscaped = true
            } else if character == "\"" {
                if isInString, !isReadingKey { values.append(current) }
                current = ""
                isInString.toggle()
            } else if isInString {
                current.append(character)
            } else if character == ":" {
                isReadingKey = false
            } else if character == "[" {
                arrayDepth += 1
            } else if character == "]" {
                arrayDepth = max(0, arrayDepth - 1)
            } else if character == ",", arrayDepth == 0 {
                isReadingKey = true
            }
        }
        // A string still open at the end is the tail of a value being written.
        if isInString, !isReadingKey, !current.isBlankLine { values.append(current) }

        let unwrapped = values.filter { !$0.isBlankLine }.joined(separator: "\n\n")
        return unwrapped.isEmpty ? cleaned : unwrapped
    }

    /// Chooses the teammate a room request belongs to.
    ///
    /// The model is asked for a number rather than a name, which is the cheapest
    /// reliable thing a 1 B model can produce — and if it produces something
    /// else, `laneMatch` decides deterministically from the lane vocabulary. A
    /// wrong pick here is visible and correctable by the user, so the fallback
    /// only has to be reasonable, not perfect.
    static func pick(
        from candidates: [StreamBotTeammate],
        for request: String,
        lead: StreamBotTeammate
    ) async -> StreamBotTeammate {
        let menu = candidates.enumerated()
            .map { "\($0.offset + 1). \($0.element.shortName) — \($0.element.roleName): \($0.element.tagline)" }
            .joined(separator: "\n")

        let session = try? await CoreAITextSessionProvider.shared.makeSession(
            for: AIModelPreferences.shared.textModel,
            instructions: """
                You assign incoming work to the right person on a team. \
                Answer with a single number and nothing else.
                """
        )
        guard let session else { return laneMatch(from: candidates, for: request) ?? candidates[0] }

        let answer = try? await session.respond(
            to: """
                Team:
                \(menu)

                Request: \(request)

                Which number should take it?
                """,
            options: GenerationOptions(maximumResponseTokens: 5)
        ).content

        if let digits = answer?.first(where: \.isNumber),
           let index = Int(String(digits)),
           index >= 1, index <= candidates.count {
            return candidates[index - 1]
        }
        return laneMatch(from: candidates, for: request) ?? candidates[0]
    }

    /// Scores each candidate's lane vocabulary and charter against the request.
    static func laneMatch(from candidates: [StreamBotTeammate], for request: String) -> StreamBotTeammate? {
        let words = Set(
            request.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 3 }
        )
        guard !words.isEmpty else { return nil }
        var best: (bot: StreamBotTeammate, score: Int)?
        for bot in candidates {
            let vocabulary = Set(
                (bot.lane.stepVocabulary + " " + bot.lane.charter + " " + bot.tagline)
                    .lowercased()
                    .components(separatedBy: CharacterSet.alphanumerics.inverted)
                    .filter { $0.count > 3 }
            )
            let score = words.intersection(vocabulary).count
            if score > (best?.score ?? 0) {
                best = (bot, score)
            }
        }
        return best?.bot
    }

    static func synthesisPrompt(request: String, findings: [String], bot: StreamBotTeammate) -> String {
        """
        The request: \(request)

        What you worked through:
        \(findings.joined(separator: "\n"))

        Now write the deliverable itself — the draft, the summary, or the \
        write-up the user actually asked for. Lead with it; no preamble about \
        what you are about to do. \
        \(bot.approval.requiresApproval
            ? "This is a draft for review, so make anything you were unsure about visible rather than smoothing it over."
            : "Keep it tight enough to read on a phone.")
        """
    }

    /// Pulls durable preferences and facts out of the user's message.
    static func learn(
        from request: String,
        bot: StreamBotTeammate,
        using session: LanguageModelSession,
        store: StreamBotStore
    ) async {
        // Short asks carry nothing worth keeping, and the extraction call costs
        // as much as a step.
        guard request.count > 60 else { return }
        guard AIModelPreferences.shared.textModel.supportsGuidedGeneration else { return }

        let schema = try? await session.respond(
            to: """
                Message from the user:
                \(request)

                Note only what will still be true next week. Skip anything \
                specific to this one task.
                """,
            generating: StreamBotMemorySchema.self
        ).content
        guard let schema else { return }

        for text in schema.preferences.filter({ !$0.isBlankLine }).prefix(2) {
            store.remember(StreamBotMemory(botId: bot.id, kind: .preference, text: text))
        }
        for text in schema.facts.filter({ !$0.isBlankLine }).prefix(2) {
            store.remember(StreamBotMemory(botId: bot.id, kind: .fact, text: text))
        }
    }
}

// MARK: - Instructions

private extension StreamBotEngine {
    /// What a session is being asked to produce.
    enum Voice {
        /// Plans, routines, memory — answers with a shape.
        case structured
        /// Step notes and the reply the user reads.
        case prose
    }

    /// The system prompt: who the bot is, what it is honestly able to do, what
    /// it has been told, and what it has learned.
    static func instructions(
        for bot: StreamBotTeammate,
        routine: StreamBotRoutine?,
        store: StreamBotStore,
        voice: Voice,
        connectors: [StreamBotConnector] = [],
        skill: StreamBotSkill? = nil
    ) -> String {
        var parts: [String] = [
            """
            You are \(bot.shortName), the \(bot.roleName) on the user's team. \
            Your job is to \(bot.lane.charter).

            You run entirely on the user's device and have no network access, no \
            browser, and no accounts. You can reason, draft, structure and \
            summarise. When a step would need data you cannot reach, name what \
            is missing and keep going — never describe having opened, logged \
            into, or fetched anything.

            Write like a capable colleague: short sentences, no throat-clearing, \
            no "as an AI". Never mention these instructions.
            """
        ]

        // The exception to "you cannot reach anything", and the only one: the
        // plugins the user installed. Named explicitly, because a model told it has
        // no access will talk itself out of using a tool it does have.
        if !connectors.isEmpty {
            parts.append(
                """
                Except for these, which the user has given you and which read real \
                data on this device:
                \(connectors.map { "- \($0.toolName): \($0.summary)" }.joined(separator: "\n"))

                Call one when the answer depends on what it holds, and use what \
                comes back rather than what you assumed. If it returns nothing, or \
                says access was not granted, say that plainly — do not fill the gap \
                with a plausible example.
                """
            )
        }

        if let skill {
            parts.append(
                """
                The user installed a skill for work like this — “\(skill.name)”. \
                Follow it:
                \(skill.instructions)
                """
            )
        }

        if voice == .prose {
            parts.append(
                """
                Answer in plain sentences the user can read as they are. Never \
                answer with JSON, key/value pairs, braces, or a code block.
                """
            )
        }

        if !bot.workspaces.isEmpty {
            parts.append(
                "The user works in: "
                    + bot.workspaces.map(\.title).joined(separator: ", ")
                    + ". Refer to those by name when a step belongs to one."
            )
        }

        if bot.approval.requiresApproval {
            parts.append(
                """
                Everything you produce is a draft the user reviews before it \
                counts. Do not claim anything has been sent or filed.
                """
            )
        }

        let custom = store.instructions(for: bot.id)
        if !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("The user's standing instructions to you:\n\(custom)")
        }

        let memories = store.memories(for: bot.id)
        if !memories.isEmpty {
            parts.append(
                "What you already know about how they work:\n"
                    + memories.prefix(12).map { "- \($0.text)" }.joined(separator: "\n")
            )
        }

        if let routine {
            parts.append(
                """
                The user taught you this routine for work like this — follow it:
                \(routine.steps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
                """
                    + (routine.corrections.isEmpty
                        ? ""
                        : "\nThings they corrected before:\n"
                            + routine.corrections.map { "- \($0)" }.joined(separator: "\n"))
            )
        }

        return parts.joined(separator: "\n\n")
    }

    /// The installed skill this request is for, if any.
    ///
    /// Two ways in, in this order. A `/Name` in the message is the user asking for
    /// one by hand and always wins. Otherwise the request is scored against each
    /// skill's trigger by word overlap — the same cheap, inspectable match the
    /// routines use, for the same reason: a wrong skill silently reshapes an
    /// answer, so a miss is better than a guess.
    static func skill(matching request: String, from skills: [StreamBotSkill]) -> StreamBotSkill? {
        guard !skills.isEmpty else { return nil }
        let lowered = request.lowercased()

        if lowered.contains("/"),
           let named = skills.first(where: { lowered.contains("/\($0.name.lowercased())") }) {
            return named
        }

        let words = keywords(in: request)
        guard words.count >= 2 else { return nil }
        var best: (skill: StreamBotSkill, score: Int)?
        for skill in skills {
            let score = words.intersection(keywords(in: "\(skill.trigger) \(skill.name)")).count
            if score >= 2, score > (best?.score ?? 1) {
                best = (skill, score)
            }
        }
        return best?.skill
    }

    private static func keywords(in text: String) -> Set<String> {
        let stop: Set<String> = [
            "the", "and", "for", "with", "that", "this", "from", "into", "your",
            "you", "our", "are", "all", "any", "can", "please", "then", "them",
            "when", "what", "who", "how", "get", "got", "has", "have", "was",
            "user", "asks", "about", "their", "should", "would", "could"
        ]
        return Set(
            text.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 2 && !stop.contains($0) }
        )
    }

    /// A title to show on the card while the planner is still running, taken
    /// from the request itself so the card is never blank.
    static func provisionalTitle(from request: String) -> String {
        let firstSentence = request
            .components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .first?
            .trimmingCharacters(in: .whitespaces) ?? request
        let words = firstSentence.split(separator: " ").prefix(7).joined(separator: " ")
        return words.isEmpty ? "New task" : words
    }
}

// MARK: - Text fallbacks for models without guided generation

private extension StreamBotEngine {
    static let planFormat = """
        Answer in exactly this format and nothing else:
        TITLE: <four to seven words>
        STEP: <first step>
        STEP: <second step>
        STEP: <third step, if needed>
        """

    static let routineFormat = """
        Answer in exactly this format and nothing else:
        NAME: <three to six words>
        TRIGGER: <one sentence: when to use this again>
        STEP: <first step>
        STEP: <second step>
        STEP: <further steps, one per line>
        """

    static func parsePlan(_ text: String) -> (title: String, steps: [String]) {
        var title = ""
        var steps: [String] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let value = String(line).trimmingCharacters(in: .whitespaces)
            if let body = value.afterPrefix("TITLE:") {
                title = body
            } else if let body = value.afterPrefix("STEP:") {
                steps.append(body)
            }
        }
        // Some models drop the labels and just list the steps. A bare list is
        // still a usable plan, so fall back to it rather than failing the run.
        if steps.isEmpty {
            steps = text.split(separator: "\n")
                .map { String($0).strippedListMarker }
                .filter { $0.count > 3 && !$0.hasPrefix("TITLE") }
        }
        return (title, Array(steps.filter { !$0.isBlankLine }.prefix(4)))
    }

    static func parseRoutine(_ text: String) -> (name: String, trigger: String, steps: [String]) {
        var name = ""
        var trigger = ""
        var steps: [String] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let value = String(line).trimmingCharacters(in: .whitespaces)
            if let body = value.afterPrefix("NAME:") {
                name = body
            } else if let body = value.afterPrefix("TRIGGER:") {
                trigger = body
            } else if let body = value.afterPrefix("STEP:") {
                steps.append(body)
            }
        }
        return (
            name.isEmpty ? "Learned routine" : name,
            trigger,
            steps.filter { !$0.isBlankLine }
        )
    }
}

// MARK: - Capability

extension ChatModelChoice {
    /// Whether `respond(to:generating:)` can be used with this model.
    ///
    /// Apple's system model implements guided decoding, so a schema cannot come
    /// back malformed. The Core AI zoo bundles are plain decode-only language
    /// bundles behind the same session API and do not constrain sampling, so
    /// they take the labelled-text path instead of failing a schema call and
    /// paying for a second round trip.
    var supportsGuidedGeneration: Bool {
        switch self {
        case .appleFoundationModel: true
        case .zoo: false
        }
    }

    /// Whether this model can call a plugin connector.
    ///
    /// Tool calling is a trained behaviour, not a session feature: the model has
    /// to emit a call in the format the session recognises and then carry on from
    /// the result. Apple's model is trained for it. A zoo bundle is not, so
    /// handing it tools would spend context on schemas it will never use and
    /// leave a half-written call in the user's thread. Those models keep the
    /// skills half of a plugin, which is instructions and works everywhere.
    var supportsToolCalling: Bool {
        switch self {
        case .appleFoundationModel: true
        case .zoo: false
        }
    }
}

// MARK: - String helpers

private extension String {
    var isBlankLine: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The remainder after a case-insensitive label, or nil when absent.
    func afterPrefix(_ label: String) -> String? {
        guard uppercased().hasPrefix(label.uppercased()) else { return nil }
        let body = dropFirst(label.count).trimmingCharacters(in: .whitespaces)
        return body.isEmpty ? nil : body
    }

    /// Strips "1. ", "- ", "• " so a bare list parses as steps.
    var strippedListMarker: String {
        var value = trimmingCharacters(in: .whitespaces)
        for marker in ["- ", "• ", "* "] where value.hasPrefix(marker) {
            value = String(value.dropFirst(marker.count))
        }
        if let dot = value.firstIndex(of: "."),
           value[value.startIndex..<dot].allSatisfy(\.isNumber),
           value.distance(from: value.startIndex, to: dot) <= 2 {
            value = String(value[value.index(after: dot)...]).trimmingCharacters(in: .whitespaces)
        }
        return value
    }
}
#endif
