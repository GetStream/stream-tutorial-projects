import SwiftUI
import UIKit

/// Color system sampled from the reference artwork: a soft periwinkle field,
/// a white core glow, and a faint prismatic halo (peach / rose / mint / sky).
enum Aurora {
    // MARK: Base field (periwinkle ramp)

    /// Lightest haze at the top-left of the field.
    static let periwinkle100 = Color(hex: 0xC9D4F1)
    /// Mid field tone - the dominant background color.
    static let periwinkle300 = Color(hex: 0xA6B6E6)
    /// Deeper field tone toward the edges.
    static let periwinkle500 = Color(hex: 0x8A9DD8)
    /// Accent - used for tinted glass and controls.
    static let periwinkle600 = Color(hex: 0x6F86D6)
    /// Deep accent for text on light surfaces.
    static let indigo800 = Color(hex: 0x2E3A6E)
    static let indigo900 = Color(hex: 0x1F2A5A)

    // MARK: Glow + prismatic halo

    static let glow = Color.white
    static let haloPeach = Color(hex: 0xF3C9B4)
    static let haloRose = Color(hex: 0xEFB9C9)
    static let haloMint = Color(hex: 0xBFE8DA)
    static let haloSky = Color(hex: 0xC7E3F7)

    // MARK: Dark-mode counterparts

    static let night100 = Color(hex: 0x2C3564)
    static let night300 = Color(hex: 0x1E264B)
    static let night500 = Color(hex: 0x141A36)

    // MARK: Semantic

    /// Primary text, adaptive.
    static let textPrimary = Color(UIColor(light: UIColor(hex: 0x1F2A5A), dark: UIColor(hex: 0xEEF1FF)))
    static let textSecondary = Color(UIColor(light: UIColor(hex: 0x46538A), dark: UIColor(hex: 0xB9C2E8)))
    static let accent = Color(UIColor(light: UIColor(hex: 0x5F78D1), dark: UIColor(hex: 0xA9B9F0)))

    /// Angular sweep used for the prismatic ring around the hero orb and avatars.
    static let prism = AngularGradient(
        colors: [haloSky, haloMint, haloPeach, haloRose, haloSky],
        center: .center
    )

    /// AI component palette (composer, suggestions, mic) that matches the field.
    static var aiComponentColors: AuroraAIColors { AuroraAIColors() }
}

/// Convenience wrappers so `Color(hex:)` / `UIColor(hex:)` read well in the theme.
extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }

    convenience init(light: UIColor, dark: UIColor) {
        self.init { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        }
    }
}

/// Thin holder so the palette is easy to pass into `StreamChatAI.Colors`.
struct AuroraAIColors {
    let attachmentButtonBackground = Color.white.opacity(0.28)
    let attachmentButtonIcon = Aurora.textPrimary
    let containerBackground = Color.clear
    let containerForeground = Aurora.textPrimary
    let selectedOptionBackground = Color.white.opacity(0.42)
    let selectedOptionForeground = Aurora.indigo800
    let suggestionText = Aurora.textPrimary
    let suggestionBackground = Color.white.opacity(0.32)
    let transcriptionIcon = Aurora.textPrimary
}
