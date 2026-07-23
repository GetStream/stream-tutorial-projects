//
//  IMessageScreens.swift
//  SwiftUIFor27
//
//  Created by Amos Gyamfi on 22.7.2026.
//
//  All chat-facing screens of the iMessage clone:
//
//    * Messages tab   — iMessage-style inbox rows over a live Stream channel
//                       list, with the Edit menu and filter menu in the
//                       toolbar (Liquid Glass) and a compose sheet.
//    * Chat screen    — Stream's ChatChannelView with a floating Liquid
//                       Glass composer and an iMessage-style contact header.
//    * Profile page   — contact card with audio/video call buttons (Stream
//                       Video), Hide Alerts (channel mute), and Block Contact.
//    * Calls tab      — FaceTime-style list with per-contact call buttons.
//    * Contacts tab   — all contacts, navigating to the profile page.
//    * Search tab     — bottom search field filtering conversations.
//
//  This file imports only the Chat SDK. Calls are started through
//  IMessageCallCoordinator, whose API is plain Foundation types, so the
//  Video SDK never leaks into this file (type names collide across SDKs).
//

#if os(iOS)
import Combine
import StreamChat
import StreamChatSwiftUI
import SwiftUI

// MARK: - Contact model

/// A person derived from a 1:1 channel: the member who isn't the current user.
struct IMessageContact: Identifiable, Hashable {
    let userId: String
    let name: String
    let cid: ChannelId

    var id: String { userId }

    init?(channel: ChatChannel) {
        guard let member = channel.lastActiveMembers.first(
            where: { $0.id != IMessageChatService.currentUserId }
        ) else { return nil }
        userId = member.id
        name = member.name ?? member.id
        cid = channel.cid
    }

    var initials: String {
        let words = name.split(separator: " ")
        if words.count >= 2, let first = words.first?.first, let last = words.last?.first {
            return "\(first)\(last)".uppercased()
        }
        return String(name.prefix(1)).uppercased()
    }

    /// First name only, for the pill under the avatar in the chat header.
    var shortName: String {
        String(name.split(separator: " ").first ?? Substring(name))
    }
}

// MARK: - Inbox view model

/// Observes the live channel list. Shared by every tab so the app keeps a
/// single ChatChannelListController.
@MainActor
final class IMessageInboxViewModel: ObservableObject, ChatChannelListControllerDelegate {
    static let shared = IMessageInboxViewModel()

    @Published private(set) var channels: [ChatChannel] = []

    private var controller: ChatChannelListController?

    private init() {}

    func startIfNeeded() {
        guard controller == nil,
              let client = IMessageChatService.shared.chatClient else { return }
        // Only channels seeded for this demo (tagged `imessage: true` via the
        // Stream CLI) — keeps other sample apps' channels out of the inbox.
        let controller = client.channelListController(
            query: .init(
                filter: .and([
                    .containMembers(userIds: [IMessageChatService.currentUserId]),
                    .equal("imessage", to: true)
                ]),
                sort: [.init(key: .lastMessageAt, isAscending: false)]
            )
        )
        self.controller = controller
        controller.delegate = self
        controller.synchronize { [weak self] _ in
            self?.reload()
        }
    }

    func controller(
        _ controller: ChatChannelListController,
        didChangeChannels changes: [ListChange<ChatChannel>]
    ) {
        reload()
    }

    private func reload() {
        guard let controller else { return }
        channels = Array(controller.channels)
    }

    var contacts: [IMessageContact] {
        channels.compactMap(IMessageContact.init(channel:))
    }
}

// MARK: - Avatar

struct IMessageAvatarView: View {
    let initials: String
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.35, green: 0.33, blue: 0.45), Color(red: 0.22, green: 0.2, blue: 0.3)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(width: size, height: size)
    }
}

// MARK: - Messages tab

/// Which mailbox the filter menu has selected.
enum IMessageMailbox: String, CaseIterable {
    case messages = "Messages"
    case spam = "Spam"
    case recentlyDeleted = "Recently Deleted"
}

struct IMessageMessagesTab: View {
    @ObservedObject private var inbox = IMessageInboxViewModel.shared
    @State private var path = NavigationPath()
    @State private var mailbox: IMessageMailbox = .messages
    @State private var unreadOnly = false
    @State private var showCompose = false

    private var visibleChannels: [ChatChannel] {
        guard mailbox == .messages else { return [] }
        return unreadOnly
            ? inbox.channels.filter { $0.unreadCount.messages > 0 }
            : inbox.channels
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if mailbox != .messages {
                    ContentUnavailableView(
                        "No \(mailbox.rawValue)",
                        systemImage: mailbox == .spam ? "xmark.bin" : "trash",
                        description: Text("Nothing here — this is a demo mailbox.")
                    )
                } else {
                    List(visibleChannels, id: \.cid) { channel in
                        Button {
                            path.append(channel.cid)
                        } label: {
                            IMessageChannelRow(channel: channel)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 8))
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(unreadOnly ? "Unread" : mailbox.rawValue)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    editMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    filterMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCompose = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .navigationDestination(for: ChannelId.self) { cid in
                IMessageChatScreen(cid: cid)
            }
            .navigationDestination(for: IMessageContact.self) { contact in
                IMessageContactProfileView(contact: contact)
            }
            .sheet(isPresented: $showCompose) {
                IMessageComposeSheet(contacts: inbox.contacts) { contact in
                    showCompose = false
                    path.append(contact.cid)
                }
            }
        }
        .onAppear { inbox.startIfNeeded() }
        .onChange(of: inbox.channels.isEmpty) { _, isEmpty in
            // UI-test hooks: `-openFirstChannel` / `-openFirstContactProfile`
            // navigate automatically once the channel list has loaded.
            guard !isEmpty, path.isEmpty,
                  let first = inbox.channels.first else { return }
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-openFirstChannel") {
                path.append(first.cid)
            } else if arguments.contains("-openFirstContactProfile"),
                      let contact = IMessageContact(channel: first) {
                path.append(contact)
            } else if arguments.contains("-autoVideoCallFirstContact"),
                      let contact = IMessageContact(channel: first) {
                IMessageCallCoordinator.shared.startVideoCall(userId: contact.userId)
            } else if arguments.contains("-autoAudioCallFirstContact"),
                      let contact = IMessageContact(channel: first) {
                IMessageCallCoordinator.shared.startAudioCall(userId: contact.userId)
            }
        }
    }

    /// iMessage's Edit menu: Select Messages, Edit Pins, Set Up Name & Photo.
    private var editMenu: some View {
        Menu("Edit") {
            Button {
                // Demo action — selection UI not implemented.
            } label: {
                Label("Select Messages", systemImage: "checkmark.circle")
            }
            Button {
                // Demo action.
            } label: {
                Label("Edit Pins", systemImage: "pin")
            }
            Button {
                // Demo action.
            } label: {
                Label("Set Up Name & Photo", systemImage: "person.crop.circle")
            }
        }
    }

    /// iMessage's filter menu: mailboxes, the unread filter, and management.
    private var filterMenu: some View {
        Menu {
            Picker("Mailbox", selection: $mailbox) {
                Label("Messages", systemImage: "bubble.left.and.bubble.right").tag(IMessageMailbox.messages)
                Label("Spam", systemImage: "xmark.bin").tag(IMessageMailbox.spam)
                Label("Recently Deleted", systemImage: "trash").tag(IMessageMailbox.recentlyDeleted)
            }
            Section("Filter By") {
                Toggle(isOn: $unreadOnly) {
                    Label("Unread", systemImage: "bubble.badge.fill")
                }
            }
            Divider()
            Button("Manage Filtering") {
                // Demo action.
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
        }
    }
}

// MARK: - Inbox row

struct IMessageChannelRow: View {
    let channel: ChatChannel

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d.M.yyyy"
        return formatter
    }()

    private var contact: IMessageContact? { IMessageContact(channel: channel) }
    private var isUnread: Bool { channel.unreadCount.messages > 0 }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(.blue)
                .frame(width: 10, height: 10)
                .opacity(isUnread ? 1 : 0)
                .padding(.top, 20)

            IMessageAvatarView(initials: contact?.initials ?? "?", size: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(contact?.name ?? channel.name ?? "Unknown")
                    .font(.headline)
                Text(channel.latestMessages.first?.text ?? "No messages yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                if let date = channel.lastMessageAt {
                    Text(Self.dateFormatter.string(from: date))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - Compose sheet

struct IMessageComposeSheet: View {
    let contacts: [IMessageContact]
    var onSelect: (IMessageContact) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(contacts) { contact in
                Button {
                    onSelect(contact)
                } label: {
                    HStack(spacing: 12) {
                        IMessageAvatarView(initials: contact.initials, size: 40)
                        Text(contact.name).font(.headline)
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Chat screen

struct IMessageChatScreen: View {
    let cid: ChannelId

    var body: some View {
        if let client = IMessageChatService.shared.chatClient {
            ChatChannelView(
                viewFactory: IMessageChatViewFactory.shared,
                channelController: client.channelController(for: cid)
            )
            .toolbar(.hidden, for: .tabBar)
        }
    }
}

// MARK: - Chat view factory (Liquid Glass composer + iMessage header)

final class IMessageChatViewFactory: ViewFactory {
    @Injected(\.chatClient) var chatClient

    static let shared = IMessageChatViewFactory()
    private init() {}

    /// iOS 26 floating Liquid Glass composer instead of the docked default.
    var styles = LiquidGlassStyles()

    func makeChannelHeaderViewModifier(
        options: ChannelHeaderViewModifierOptions
    ) -> some ChatChannelHeaderViewModifier {
        IMessageChannelHeaderModifier(channel: options.channel)
    }
}

/// iMessage-style header: centered avatar with a "name ›" pill navigating to
/// the contact profile, plus a trailing FaceTime button.
struct IMessageChannelHeaderModifier: ChatChannelHeaderViewModifier {
    var channel: ChatChannel

    private var contact: IMessageContact? { IMessageContact(channel: channel) }

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .principal) {
                if let contact {
                    NavigationLink(value: contact) {
                        VStack(spacing: 2) {
                            IMessageAvatarView(initials: contact.initials, size: 36)
                            HStack(spacing: 2) {
                                Text(contact.shortName)
                                    .font(.caption2)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if let contact {
                    Button {
                        IMessageCallCoordinator.shared.startVideoCall(userId: contact.userId)
                    } label: {
                        Image(systemName: "video")
                    }
                }
            }
        }
    }
}

// MARK: - Contact profile page

struct IMessageContactProfileView: View {
    let contact: IMessageContact

    @State private var hideAlerts = false
    @State private var showInSharedWithYou = true
    @State private var autoTranslate = false
    @State private var showBlockConfirm = false
    @State private var isBlocked = false

    var body: some View {
        List {
            Section {
                VStack(spacing: 14) {
                    IMessageAvatarView(initials: contact.initials, size: 96)
                        .glassEffect(.regular.tint(.white.opacity(0.08)), in: .circle)

                    Text(contact.name)
                        .font(.title2.bold())

                    GlassEffectContainer(spacing: 18) {
                        HStack(spacing: 18) {
                            Button {
                                IMessageCallCoordinator.shared.startAudioCall(userId: contact.userId)
                            } label: {
                                Image(systemName: "phone.fill")
                                    .font(.headline)
                                    .frame(width: 52, height: 52)
                                    .glassEffect(.regular.interactive(), in: .circle)
                            }
                            .buttonStyle(.plain)

                            Button {
                                IMessageCallCoordinator.shared.startVideoCall(userId: contact.userId)
                            } label: {
                                Image(systemName: "video.fill")
                                    .font(.headline)
                                    .frame(width: 52, height: 52)
                                    .glassEffect(.regular.interactive(), in: .circle)
                            }
                            .buttonStyle(.plain)

                            Image(systemName: "envelope.fill")
                                .font(.headline)
                                .foregroundStyle(.tertiary)
                                .frame(width: 52, height: 52)
                                .glassEffect(.regular, in: .circle)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                Toggle("Hide Alerts", isOn: $hideAlerts)
                Toggle("Show in Shared with You", isOn: $showInSharedWithYou)
            }

            Section {
                Toggle("Automatically Translate", isOn: $autoTranslate)
            }

            Section {
                Button("Show in Contacts") {
                    // Demo action — the system Contacts app is out of scope.
                }
                .foregroundStyle(.blue)
            }

            Section {
                Button(isBlocked ? "Unblock Contact" : "Block Contact", role: .destructive) {
                    showBlockConfirm = true
                }
            } footer: {
                Text("This conversation is not encrypted. Learn more…")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    // Demo action.
                }
            }
        }
        .confirmationDialog(
            isBlocked ? "Unblock \(contact.name)?" : "Block \(contact.name)?",
            isPresented: $showBlockConfirm,
            titleVisibility: .visible
        ) {
            Button(isBlocked ? "Unblock" : "Block", role: isBlocked ? nil : .destructive) {
                toggleBlocked()
            }
        }
        .onAppear(perform: loadMuteState)
        .onChange(of: hideAlerts) { _, muted in
            updateMute(muted)
        }
    }

    private func loadMuteState() {
        guard let client = IMessageChatService.shared.chatClient else { return }
        hideAlerts = client.channelController(for: contact.cid).channel?.isMuted ?? false
    }

    private func updateMute(_ muted: Bool) {
        guard let client = IMessageChatService.shared.chatClient else { return }
        let controller = client.channelController(for: contact.cid)
        if muted {
            controller.muteChannel()
        } else {
            controller.unmuteChannel()
        }
    }

    private func toggleBlocked() {
        guard let client = IMessageChatService.shared.chatClient else { return }
        let targetBlocked = !isBlocked
        Task {
            do {
                let connectedUser = try client.makeConnectedUser()
                if targetBlocked {
                    try await connectedUser.blockUser(contact.userId)
                } else {
                    try await connectedUser.unblockUser(contact.userId)
                }
                isBlocked = targetBlocked
            } catch {
                print("iMessage clone: block/unblock failed: \(error)")
            }
        }
    }
}

// MARK: - Calls tab

struct IMessageCallsTab: View {
    @ObservedObject private var inbox = IMessageInboxViewModel.shared

    var body: some View {
        NavigationStack {
            List(inbox.contacts) { contact in
                HStack(spacing: 12) {
                    IMessageAvatarView(initials: contact.initials, size: 44)

                    Text(contact.name).font(.headline)

                    Spacer()

                    GlassEffectContainer(spacing: 10) {
                        HStack(spacing: 10) {
                            Button {
                                IMessageCallCoordinator.shared.startAudioCall(userId: contact.userId)
                            } label: {
                                Image(systemName: "phone.fill")
                                    .font(.subheadline)
                                    .frame(width: 38, height: 38)
                                    .glassEffect(.regular.interactive(), in: .circle)
                            }
                            .buttonStyle(.plain)

                            Button {
                                IMessageCallCoordinator.shared.startVideoCall(userId: contact.userId)
                            } label: {
                                Image(systemName: "video.fill")
                                    .font(.subheadline)
                                    .frame(width: 38, height: 38)
                                    .glassEffect(.regular.interactive(), in: .circle)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .foregroundStyle(.blue)
                }
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 12))
            }
            .listStyle(.plain)
            .navigationTitle("Calls")
        }
        .onAppear { IMessageInboxViewModel.shared.startIfNeeded() }
    }
}

// MARK: - Contacts tab

struct IMessageContactsTab: View {
    @ObservedObject private var inbox = IMessageInboxViewModel.shared

    var body: some View {
        NavigationStack {
            List(inbox.contacts) { contact in
                NavigationLink(value: contact) {
                    HStack(spacing: 12) {
                        IMessageAvatarView(initials: contact.initials, size: 44)
                        Text(contact.name).font(.headline)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Contacts")
            .navigationDestination(for: IMessageContact.self) { contact in
                IMessageContactProfileView(contact: contact)
            }
        }
        .onAppear { IMessageInboxViewModel.shared.startIfNeeded() }
    }
}

// MARK: - Search tab

struct IMessageSearchTab: View {
    @ObservedObject private var inbox = IMessageInboxViewModel.shared
    @State private var query = ""

    private var results: [ChatChannel] {
        guard !query.isEmpty else { return inbox.channels }
        return inbox.channels.filter { channel in
            let name = IMessageContact(channel: channel)?.name ?? channel.name ?? ""
            let preview = channel.latestMessages.first?.text ?? ""
            return name.localizedCaseInsensitiveContains(query)
                || preview.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List(results, id: \.cid) { channel in
                NavigationLink(value: channel.cid) {
                    IMessageChannelRow(channel: channel)
                }
                .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 8))
            }
            .listStyle(.plain)
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Search conversations")
            .navigationDestination(for: ChannelId.self) { cid in
                IMessageChatScreen(cid: cid)
            }
            .navigationDestination(for: IMessageContact.self) { contact in
                IMessageContactProfileView(contact: contact)
            }
        }
        .onAppear { IMessageInboxViewModel.shared.startIfNeeded() }
    }
}
#endif
