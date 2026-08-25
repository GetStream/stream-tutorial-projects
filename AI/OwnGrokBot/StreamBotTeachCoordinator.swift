#if os(iOS)
// StreamBotTeachCoordinator.swift
// "Teach as routine", from the long-press menu to a saved routine.
//
// This exists as its own object because the action starts in a message overlay
// that is dismissed immediately afterwards. Owning the work in a singleton means
// the distillation survives the menu closing, and the result can be reported by
// whatever screen the user happens to be on when the model finishes.

import Foundation
import Observation
import StreamChat

@MainActor
@Observable
final class StreamBotTeachCoordinator {
    static let shared = StreamBotTeachCoordinator()

    enum State: Equatable {
        case idle
        case learning(String)
        case learned(String)
        case failed(String)
    }

    private(set) var state: State = .idle

    private var controllers: [String: ChatChannelController] = [:]

    private init() {}

    /// Ignores a second tap while a distillation is already running — teaching
    /// the same thread twice would produce two copies of one routine.
    func teach(bot: StreamBotTeammate, in cid: ChannelId) {
        if case .learning = state { return }
        guard let client = StreamBotChatService.shared.chatClient else { return }
        state = .learning(bot.shortName)

        let controller = controllers[cid.rawValue] ?? client.channelController(for: cid)
        controllers[cid.rawValue] = controller

        Task { [weak self] in
            guard let self else { return }
            // The thread has to be loaded before it can be read back: the user
            // may have opened this channel from a push notification and only the
            // last page is in the local store.
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                controller.synchronize { _ in continuation.resume() }
            }
            do {
                let routine = try await StreamBotEngine.shared.teachRoutine(
                    from: Array(controller.messages),
                    bot: bot,
                    in: cid
                )
                state = .learned(routine.name)
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func dismiss() { state = .idle }
}
#endif
