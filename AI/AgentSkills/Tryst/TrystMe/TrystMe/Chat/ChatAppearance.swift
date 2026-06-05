//
//  ChatAppearance.swift
//  TrystMe
//
//  ISOLATED Stream Chat file (StreamChat + StreamChatSwiftUI only).
//  Brand theming applied to the Chat UI before the StreamChat wrapper is built.
//

import SwiftUI
import UIKit
import StreamChat
import StreamChatSwiftUI

enum ChatAppearance {
    static func make() -> Appearance {
        let brand = UIColor(red: 0.99, green: 0.27, blue: 0.45, alpha: 1) // Brand.pink

        var colors = Appearance.ColorPalette()
        colors.accentPrimary = brand
        colors.navigationBarTintColor = brand
        colors.chatBackgroundOutgoing = brand.withAlphaComponent(0.14)

        var fonts = Appearance.FontsSwiftUI()
        fonts.body = .system(size: 16, weight: .regular)
        fonts.headline = .system(size: 17, weight: .semibold)

        var images = Appearance.Images()
        images.composerSend = UIImage(systemName: "paperplane.fill")!

        var appearance = Appearance()
        appearance.colorPalette = colors
        appearance.fontsSwiftUI = fonts
        appearance.images = images
        return appearance
    }
}
