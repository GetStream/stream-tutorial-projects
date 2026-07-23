//
//  IMessageCallService.swift
//  SwiftUIFor27
//
//  Created by Amos Gyamfi on 22.7.2026.
//
//  Owns the Stream Video client for the iMessage clone, plus everything
//  call-related: the call coordinator (the only calling API the rest of the
//  app touches), the FaceTime-style Liquid Glass call UI, and the root
//  wrapper that overlays call screens on top of the app.
//
//  Video SDK construction is isolated in this file — the Chat SDK lives in
//  IMessageChatService.swift and the two are never imported together
//  (User/Token/ViewFactory names collide across the SDKs).
//

#if os(iOS)
import SwiftUI
import StreamVideo
import StreamVideoSwiftUI

// MARK: - Client ownership

@MainActor
final class IMessageCallService {
    static let shared = IMessageCallService()

    private(set) var streamVideo: StreamVideo?
    private var streamVideoUI: StreamVideoUI?   // must stay alive; not exposed

    private init() {}

    /// Same API key, user, and CLI-minted JWT as the Chat side — one Stream
    /// app and one token cover both products.
    private enum Credentials {
        static let apiKey = "4dz7gst7phy5"
        static let userId = "amos"
        static let userName = "Amos Gyamfi"
        static let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjE3ODQ3MDg3OTksInVzZXJfaWQiOiJhbW9zIn0.oHLkGt_ogk4xtBZM7CNNX5RE1Du5RCRd6e4WLzutH2E"
    }

    func setUpIfNeeded() {
        guard streamVideo == nil else { return }

        #if targetEnvironment(simulator)
        // Simulators have no camera. Feed the SDK a bundled clip so the
        // local video track streams real frames instead of staying blank
        // (without this, the SDK also forces callSettings.videoOn to false).
        InjectedValues[\.simulatorStreamFile] = Bundle.main.url(
            forResource: "simulator-camera",
            withExtension: "mp4"
        )
        #endif

        let user = User(
            id: Credentials.userId,
            name: Credentials.userName,
            imageURL: nil,
            customData: [:]
        )
        let client = StreamVideo(
            apiKey: Credentials.apiKey,
            user: user,
            token: UserToken(rawValue: Credentials.token)
        )
        streamVideo = client
        streamVideoUI = StreamVideoUI(streamVideo: client)
    }
}

// MARK: - Call coordinator

/// The single calling entry point for the rest of the app. Its public API
/// uses only Foundation types, so chat files can start calls without ever
/// importing StreamVideo.
@MainActor
final class IMessageCallCoordinator {
    static let shared = IMessageCallCoordinator()

    /// Registered by `IMessageCallRoot` — the one CallViewModel that drives
    /// every call screen in the app.
    fileprivate weak var callViewModel: CallViewModel?

    private init() {}

    /// Audio calls ring the contact and show the FaceTime-style outgoing
    /// screen until they answer.
    func startAudioCall(userId: String) {
        guard let callViewModel else { return }
        syncCameraSetting(videoOn: false)
        callViewModel.startCall(
            callType: "default",
            callId: UUID().uuidString,
            members: [Member(userId: userId)],
            ring: true,
            video: false
        )
    }

    /// Video calls join immediately — same flow as StreamVideoCalling.swift.
    /// The caller lands in the call alone, so the SDK shows the waiting
    /// local-user view: the local camera feed fullscreen with the glass top
    /// bar and call controls overlaid. The contact is added as a member and
    /// can join from any device.
    func startVideoCall(userId: String) {
        guard let callViewModel else { return }
        syncCameraSetting(videoOn: true)
        callViewModel.startCall(
            callType: "default",
            callId: UUID().uuidString,
            members: [Member(userId: userId)],
            video: true
        )
    }

    /// Aligns local call settings with the call kind before dialing: audio
    /// calls start with the camera off, video calls with it on. With no
    /// active call, toggleCameraEnabled() just flips the local settings,
    /// which the join respects.
    private func syncCameraSetting(videoOn: Bool) {
        guard let callViewModel,
              callViewModel.call == nil,
              callViewModel.callSettings.videoOn != videoOn else { return }
        callViewModel.toggleCameraEnabled()
    }
}

// MARK: - Root wrapper

/// Wraps the app's content and overlays outgoing, incoming, and active call
/// screens via `CallModifier`. Owns the app-wide `CallViewModel`.
struct IMessageCallRoot<Content: View>: View {
    @StateObject private var callViewModel = CallViewModel()
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .modifier(
                CallModifier(
                    viewFactory: IMessageCallViewFactory.shared,
                    viewModel: callViewModel
                )
            )
            .onAppear {
                IMessageCallCoordinator.shared.callViewModel = callViewModel
            }
    }
}

// MARK: - View factory (Liquid Glass call slots)

final class IMessageCallViewFactory: ViewFactory {
    static let shared = IMessageCallViewFactory()
    private init() {}

    func makeCallTopView(viewModel: CallViewModel) -> some View {
        IMessageCallTopView(viewModel: viewModel)
    }

    func makeCallControlsView(viewModel: CallViewModel) -> some View {
        IMessageCallControlsView(viewModel: viewModel)
    }

    func makeIncomingCallView(viewModel: CallViewModel, callInfo: IncomingCall) -> some View {
        IMessageIncomingCallView(callInfo: callInfo, viewModel: viewModel)
    }

    func makeOutgoingCallView(viewModel: CallViewModel) -> some View {
        IMessageOutgoingCallView(viewModel: viewModel)
    }

    func makeWaitingLocalUserView(viewModel: CallViewModel) -> some View {
        IMessageWaitingLocalUserView(viewModel: viewModel)
    }
}

// MARK: - Waiting view: local camera fullscreen (Liquid Glass overlays)

/// Shown while the local user is alone in the call — which is where a video
/// call lands right after it is initiated. Renders the local camera feed
/// edge-to-edge with the glass top bar and call controls floating above it,
/// mirroring GlassWaitingLocalUserView in StreamVideoCalling.swift.
struct IMessageWaitingLocalUserView: View {
    @ObservedObject var viewModel: CallViewModel

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                if let localParticipant = viewModel.localParticipant {
                    LocalVideoView(
                        viewFactory: IMessageCallViewFactory.shared,
                        participant: localParticipant,
                        idSuffix: "waiting",
                        callSettings: viewModel.callSettings,
                        call: viewModel.call,
                        availableFrame: proxy.frame(in: .global)
                    )
                } else {
                    LinearGradient(
                        colors: [.blue.opacity(0.55), .black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .ignoresSafeArea()

            VStack {
                IMessageCallTopView(viewModel: viewModel)
                Spacer()
                IMessageCallControlsView(viewModel: viewModel)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .presentParticipantListView(
            viewModel: viewModel,
            viewFactory: IMessageCallViewFactory.shared
        )
    }
}

// MARK: - Call top bar (Liquid Glass)

struct IMessageCallTopView: View {
    @ObservedObject var viewModel: CallViewModel

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                // Minimize the call to a floating picture-in-picture view
                Button {
                    viewModel.isMinimized = true
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.headline)
                        .frame(width: 42, height: 42)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)

                Spacer()

                // Live indicator + call duration
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(viewModel.recordingState == .recording ? .red : .green)
                            .frame(width: 8, height: 8)
                        Text(durationText)
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .glassEffect(.regular.tint(.black.opacity(0.15)), in: .capsule)
                }

                Spacer()

                // Participants list with count
                Button {
                    viewModel.participantsShown.toggle()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "person.2.fill")
                            .font(.headline)
                        Text("\(max(viewModel.callParticipants.count, 1))")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var durationText: String {
        let duration = Int(viewModel.call?.state.duration ?? 0)
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Outgoing call (audio, FaceTime-style)

/// Shown while an audio call rings the contact (video calls join
/// immediately and never pass through this state).
struct IMessageOutgoingCallView: View {
    @Injected(\.streamVideo) var streamVideo
    @Injected(\.utils) var utils

    @ObservedObject var viewModel: CallViewModel

    private var callee: Member? {
        let members = viewModel.outgoingCallMembers.isEmpty
            ? (streamVideo.state.ringingCall?.state.members ?? [])
            : viewModel.outgoingCallMembers
        return members.first { $0.id != streamVideo.user.id }
    }

    private var calleeName: String {
        callee?.user.name ?? callee?.id ?? "Unknown"
    }

    private var calleeInitials: String {
        let words = calleeName.split(separator: " ")
        if words.count >= 2, let first = words.first?.first, let last = words.last?.first {
            return "\(first)\(last)".uppercased()
        }
        return String(calleeName.prefix(1)).uppercased()
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.blue.opacity(0.55), .black, .indigo.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                VStack(spacing: 12) {
                    Text(calleeInitials)
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 104, height: 104)
                        .glassEffect(.regular.tint(.white.opacity(0.15)), in: .circle)
                        .padding(.top, 48)

                    VStack(spacing: 6) {
                        Text(calleeName)
                            .font(.title.bold())
                            .foregroundStyle(.white)
                        Text("Calling…")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .glassEffect(.regular, in: .capsule)
                    }
                }

                Spacer()

                IMessageCallControlsView(viewModel: viewModel)
            }
        }
        .onAppear {
            utils.callSoundsPlayer.playOutgoingCallSound()
        }
        .onDisappear {
            utils.callSoundsPlayer.stopOngoingSound()
        }
    }
}

// MARK: - Call controls (Liquid Glass)

struct IMessageCallControlsView: View {
    @ObservedObject var viewModel: CallViewModel

    var body: some View {
        GlassEffectContainer(spacing: 14) {
            HStack(spacing: 14) {
                Button {
                    viewModel.toggleMicrophoneEnabled()
                } label: {
                    Image(systemName: viewModel.callSettings.audioOn ? "mic.fill" : "mic.slash.fill")
                        .font(.title3)
                        .frame(width: 56, height: 56)
                        .glassEffect(
                            .regular.tint(viewModel.callSettings.audioOn ? .clear : .red.opacity(0.4)).interactive(),
                            in: .circle
                        )
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.toggleCameraEnabled()
                } label: {
                    Image(systemName: viewModel.callSettings.videoOn ? "video.fill" : "video.slash.fill")
                        .font(.title3)
                        .frame(width: 56, height: 56)
                        .glassEffect(
                            .regular.tint(viewModel.callSettings.videoOn ? .clear : .red.opacity(0.4)).interactive(),
                            in: .circle
                        )
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.toggleSpeaker()
                } label: {
                    Image(systemName: viewModel.callSettings.speakerOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.title3)
                        .frame(width: 56, height: 56)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)

                Button {
                    Task { try? await viewModel.call?.camera.flip() }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                        .font(.title3)
                        .frame(width: 56, height: 56)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.hangUp()
                } label: {
                    Image(systemName: "phone.down.fill")
                        .font(.title3)
                        .frame(width: 56, height: 56)
                        .glassEffect(.regular.tint(.red.opacity(0.85)).interactive(), in: .circle)
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

// MARK: - Incoming call (FaceTime-style Liquid Glass)

struct IMessageIncomingCallView: View {
    let callInfo: IncomingCall
    @ObservedObject var viewModel: CallViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.blue.opacity(0.55), .black, .indigo.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                AsyncImage(url: callInfo.caller.imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Text(String(callInfo.caller.name.prefix(1)).uppercased())
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .frame(width: 110, height: 110)
                .clipShape(.circle)
                .glassEffect(.regular.tint(.white.opacity(0.15)), in: .circle)

                VStack(spacing: 8) {
                    Text(callInfo.caller.name)
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Text(callInfo.video ? "Incoming video call…" : "Incoming audio call…")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .glassEffect(.regular, in: .capsule)
                }

                Spacer()

                GlassEffectContainer(spacing: 56) {
                    HStack(spacing: 56) {
                        Button {
                            viewModel.rejectCall(callType: callInfo.type, callId: callInfo.id)
                        } label: {
                            Image(systemName: "phone.down.fill")
                                .font(.title)
                                .frame(width: 74, height: 74)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.red)

                        Button {
                            viewModel.acceptCall(callType: callInfo.type, callId: callInfo.id)
                        } label: {
                            Image(systemName: callInfo.video ? "video.fill" : "phone.fill")
                                .font(.title)
                                .frame(width: 74, height: 74)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.green)
                    }
                }
                .foregroundStyle(.white)
                .padding(.bottom, 48)
            }
        }
    }
}
#endif
