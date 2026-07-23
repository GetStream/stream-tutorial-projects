//
//  iMessageCloneStreamSkillsApp.swift
//  SwiftUIFor27
//
//  Created by Amos Gyamfi on 22.7.2026.
//
//  Root of the iMessage clone built with Stream's Agent Skills. This file
//  intentionally imports neither Stream SDK — Chat construction lives in
//  IMessageChatService.swift and Video construction in
//  IMessageCallService.swift (type names collide across the two SDKs, so
//  each is isolated in its own file).
//
//  Structure:
//    * Tab bar (Liquid Glass) — Messages, Calls, Contacts, and Search.
//    * IMessageCallRoot      — overlays outgoing/incoming/active call
//                              screens app-wide via Stream Video.
//

#if os(iOS)
import SwiftUI

struct iMessageCloneStreamSkillsApp: View {
    init() {
        IMessageChatService.shared.setUpIfNeeded()
        IMessageCallService.shared.setUpIfNeeded()
    }

    var body: some View {
        IMessageCallRoot {
            TabView {
                Tab("Messages", systemImage: "bubble.left.and.bubble.right.fill") {
                    IMessageMessagesTab()
                }
                Tab("Calls", systemImage: "phone.fill") {
                    IMessageCallsTab()
                }
                Tab("Contacts", systemImage: "person.crop.circle.fill") {
                    IMessageContactsTab()
                }
                Tab("Search", systemImage: "magnifyingglass", role: .search) {
                    IMessageSearchTab()
                }
            }
            .tint(.blue)
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    iMessageCloneStreamSkillsApp()
}
#endif
