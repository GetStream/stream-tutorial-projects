#if os(iOS)
// StreamBotRunCardView.swift
// The plan, live, inside a message bubble.
//
// This is the view that carries the app's central idea: work you hand off is
// something you can watch and stop, not a spinner that eventually produces
// text. Every step shows its own state and the note the bot wrote when it
// finished, so a run that went wrong shows *where* it went wrong.
//
// The card stays interactive after the run ends. Approve and Reject are on the
// card rather than in the composer because a parked draft may be reviewed hours
// later, from the middle of a scrolled-back thread.

import StreamChat
import SwiftUI

struct StreamBotRunCardView: View {
    let run: StreamBotRun
    let bot: StreamBotTeammate
    let messageId: MessageId
    let cid: ChannelId
    /// Whether the runtime still had this message open on its last write.
    let isStreaming: Bool

    @State private var isRejecting = false
    @State private var rejectionReason = ""
    @State private var isExpanded = true

    private var accent: Color { bot.color }

    /// A run whose message is still flagged as being written, but which nothing
    /// is working on any more — the app was killed mid-run.
    ///
    /// This is why the flag is written at all. Without it, reopening the thread
    /// after a crash would show a plan frozen on step two with a spinner that
    /// never resolves. With it, the card offers to start again.
    private var isAbandoned: Bool {
        isStreaming
            && run.status.isRunning
            && !StreamBotEngine.shared.isBusy(in: cid)
    }

    var body: some View {
        StreamBotCard(tint: accent) {
            VStack(alignment: .leading, spacing: 12) {
                header
                if !run.steps.isEmpty {
                    StreamBotProgressTrack(fraction: run.progress, tint: accent)
                }
                if isExpanded {
                    steps
                }
                if let note = run.note, !note.isEmpty {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(run.status == .failed ? .red : .streamBotSecondary)
                }
                actions
            }
        }
        .frame(maxWidth: 320, alignment: .leading)
        .animation(.smooth(duration: 0.28), value: run.steps)
        .animation(.smooth(duration: 0.28), value: run.status)
        .alert("Send it back?", isPresented: $isRejecting) {
            TextField("What was wrong with it?", text: $rejectionReason)
            Button("Cancel", role: .cancel) { rejectionReason = "" }
            Button("Reject") {
                StreamBotEngine.shared.reject(
                    run,
                    reason: rejectionReason,
                    messageId: messageId,
                    bot: bot,
                    in: cid
                )
                rejectionReason = ""
            }
        } message: {
            Text("\(bot.shortName) keeps what you say here and applies it next time.")
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            StreamBotAvatar(
                symbolName: bot.symbolName,
                accent: accent,
                size: 32,
                isWorking: run.status.isRunning
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(run.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                HStack(spacing: 5) {
                    StreamBotPill(
                        text: run.status.title,
                        symbolName: run.status.symbolName,
                        tint: statusTint,
                        isProminent: true
                    )
                    if !run.steps.isEmpty {
                        Text("\(run.completedStepCount)/\(run.steps.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.streamBotSecondary)
                    }
                    if run.routineId != nil {
                        Image(systemName: "graduationcap.fill")
                            .font(.caption2)
                            .foregroundStyle(.streamBotSecondary)
                            .streamBotRepeatingSymbolEffect(for: "graduationcap.fill")
                            .accessibilityLabel("Replayed a learned routine")
                    }
                }
            }
            Spacer(minLength: 0)
            if !run.steps.isEmpty {
                Button {
                    withAnimation(.smooth(duration: 0.25)) { isExpanded.toggle() }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .foregroundStyle(.streamBotSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "Hide steps" : "Show steps")
            }
        }
    }

    private var statusTint: Color {
        switch run.status {
        case .planning, .working: accent
        case .awaitingApproval: .orange
        case .approved, .done: .green
        case .rejected, .failed: .red
        case .interrupted: .streamBotSecondary
        }
    }

    // MARK: Steps

    private var steps: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(run.steps) { step in
                HStack(alignment: .top, spacing: 8) {
                    stepIcon(for: step)
                        .frame(width: 16, height: 16)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .font(.footnote.weight(step.status == .active ? .semibold : .regular))
                            .foregroundStyle(step.status == .pending ? Color.streamBotSecondary : Color.primary)
                        if let note = step.note, !note.isEmpty {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.streamBotSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let workspace = step.workspace {
                            StreamBotPill(text: workspace.title, symbolName: workspace.symbolName)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        // Step symbols share the metrics of the titles they sit beside.
        .font(.footnote)
    }

    @ViewBuilder
    private func stepIcon(for step: StreamBotRunStep) -> some View {
        switch step.status {
        case .pending:
            Image(systemName: "circle.dotted")
                .foregroundStyle(.streamBotSecondary)
                .streamBotRepeatingSymbolEffect(for: "circle.dotted")
        case .active:
            // A spinner rather than a symbol: this is the one row in the card
            // where the user is waiting on something.
            ProgressView().controlSize(.mini)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .streamBotAccentText(accent)
                .streamBotRepeatingSymbolEffect(for: "checkmark.circle.fill")
        case .blocked:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
                .streamBotRepeatingSymbolEffect(for: "exclamationmark.circle.fill")
        case .skipped:
            Image(systemName: "minus.circle")
                .foregroundStyle(.streamBotSecondary)
                .streamBotRepeatingSymbolEffect(for: "minus.circle")
        }
    }

    // MARK: Actions

    @ViewBuilder
    private var actions: some View {
        if isAbandoned {
            StreamBotActionButton(title: "Resume", symbolName: "play.fill", size: .small) {
                StreamBotEngine.shared.retry(run, bot: bot, in: cid)
            }
        } else {
            liveActions
        }
    }

    @ViewBuilder
    private var liveActions: some View {
        switch run.status {
        case .awaitingApproval:
            HStack(spacing: 8) {
                StreamBotActionButton(
                    title: "Approve",
                    symbolName: "checkmark",
                    isProminent: true,
                    tint: accent,
                    size: .small
                ) {
                    StreamBotEngine.shared.approve(
                        run,
                        messageId: messageId,
                        bot: bot,
                        in: cid
                    )
                }
                StreamBotActionButton(title: "Send back", symbolName: "arrow.uturn.left", size: .small) {
                    isRejecting = true
                }
            }
        case .planning, .working:
            StreamBotActionButton(title: "Stop", symbolName: "stop.fill", size: .small) {
                StreamBotEngine.shared.cancel(in: cid)
            }
        case .failed, .rejected, .interrupted:
            StreamBotActionButton(title: "Try again", symbolName: "arrow.clockwise", size: .small) {
                StreamBotEngine.shared.retry(run, bot: bot, in: cid)
            }
        case .approved, .done:
            if let result = run.result, !result.isEmpty {
                ShareLink(item: "\(run.title)\n\n\(result)") {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .tint(.primary)
                .foregroundStyle(.primary)
            }
        }
    }
}

// MARK: - Reply bubble

/// A bot's prose answer.
///
/// Rendered by the view factory rather than left to the SDK's text view for one
/// reason: the caret. While the runtime is still editing the message, the bubble
/// shows a block cursor, which is the difference between "still writing" and
/// "that is the whole answer".
struct StreamBotReplyView: View {
    let text: String
    let bot: StreamBotTeammate?
    let isStreaming: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let bot {
                HStack(spacing: 5) {
                    Image(systemName: bot.symbolName)
                        .font(.system(size: 9, weight: .bold))
                        .streamBotRepeatingSymbolEffect(for: bot.symbolName)
                    Text(bot.shortName)
                        .font(.caption2.weight(.semibold))
                }
                .streamBotAccentText(bot.color)
            }

            if text.isEmpty, isStreaming {
                StreamBotThinkingDots(tint: bot?.color ?? .streamBotSecondary)
                    .padding(.vertical, 3)
            } else {
                StreamBotStreamingText(text: text, showsCaret: isStreaming)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

// MARK: - Routine confirmation

/// The note a bot posts when it has learned something. Deliberately small and
/// quiet — it is a receipt, not a result.
struct StreamBotRoutineNoteView: View {
    let name: String
    let detail: String
    let bot: StreamBotTeammate?

    var body: some View {
        StreamBotCard(tint: bot?.color, cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "graduationcap.fill")
                        .font(.caption)
                        .streamBotRepeatingSymbolEffect(for: "graduationcap.fill")
                    Text("Learned a routine")
                        .font(.caption.weight(.semibold))
                }
                .streamBotAccentText(bot?.color ?? .streamBot)
                Text(name)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.streamBotSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: 300, alignment: .leading)
    }
}
#endif
