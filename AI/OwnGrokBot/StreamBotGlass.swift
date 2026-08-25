#if os(iOS)
// StreamBotGlass.swift
// StreamBot's look: the Stream appearance override that makes the SDK's chat
// read like Grok Bot, plus the Liquid Glass primitives every screen reuses.
//
// Two rules run through this file.
//
// 1. Anything tappable is a `Button` with a native glass button style
//    (`.glass` / `.glassProminent` plus `.buttonBorderShape`), never a
//    `.glassEffect()` wrapped around a tap gesture. The button style derives
//    its hit shape from the same geometry it draws, so the touch target always
//    matches the glass. A decorated container with a gesture looks identical
//    and misses taps around its edges.
//
// 2. `.glassEffect()` is for surfaces that only display: cards, pills, status
//    strips, the run card. Those never need a hit shape, so the modifier is the
//    right tool and `GlassEffectContainer` can morph them safely.

import StreamChat
import StreamChatSwiftUI
import SwiftUI
import UIKit

// MARK: - Brand

extension Color {
    /// StreamBot's brand colour, `#005fff`.
    ///
    /// Everything the app itself owns is this one blue: the tab bar, the send
    /// button, outgoing bubbles, progress, and the backdrop behind the glass. A
    /// teammate's accent is only ever allowed on that teammate — its avatar,
    /// its run card, its row — so colour always means "this bot" and never
    /// "this control".
    static let streamBot = Color(red: 0, green: 95 / 255, blue: 1)

    /// Supporting copy on glass.
    ///
    /// System `.secondary` is a blue-grey that sinks into Liquid Glass in dark
    /// mode, and a bot's `#005fff` accent is worse still as type. This stays a
    /// bright grey in the dark and a charcoal in the light, so captions, notes,
    /// and chrome all read as the same ink.
    static let streamBotSecondary = Color(
        uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                UIColor(red: 0.84, green: 0.88, blue: 0.94, alpha: 1)
            } else {
                UIColor(red: 0.29, green: 0.33, blue: 0.40, alpha: 1)
            }
        }
    )

    /// Metadata — timestamps, placeholders — a step quieter than secondary,
    /// still above a 4.5:1 contrast on the backdrop.
    static let streamBotTertiary = Color(
        uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                UIColor(red: 0.70, green: 0.75, blue: 0.84, alpha: 1)
            } else {
                UIColor(red: 0.42, green: 0.46, blue: 0.52, alpha: 1)
            }
        }
    )

    /// An accent lifted so it can be used as type or an icon on dark glass.
    /// Saturated brand blue is kept for fills (bubbles, toggles, avatars).
    func streamBotOnGlass(in scheme: ColorScheme) -> Color {
        scheme == .dark ? mix(with: .white, by: 0.58) : self
    }
}

extension ShapeStyle where Self == Color {
    static var streamBot: Color { Color.streamBot }
    static var streamBotSecondary: Color { Color.streamBotSecondary }
    static var streamBotTertiary: Color { Color.streamBotTertiary }
}

extension View {
    /// Accent as type or an icon on glass — lifted in dark mode so `#005fff`
    /// does not disappear into the backdrop.
    func streamBotAccentText(_ color: Color) -> some View {
        modifier(StreamBotAccentText(color: color))
    }
}

private struct StreamBotAccentText: ViewModifier {
    let color: Color
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.foregroundStyle(color.streamBotOnGlass(in: colorScheme))
    }
}

extension UIColor {
    /// The same `#005fff`, for the parts of the Stream SDK that take `UIColor`.
    static let streamBot = UIColor(Color.streamBot)
}

// MARK: - Stream appearance

/// Retunes the Stream SDK to StreamBot's palette.
///
/// The thread is brand blue and greys, nothing else: the user's own bubble is
/// `#005fff` with white text, bot bubbles are the system surface, and the only
/// other colour in a thread comes from the teammate's accent on its avatar and
/// run card. That keeps nine differently-badged bots legible in one list
/// instead of turning the app into a paint chart.
@MainActor
enum StreamBotAppearance {
    static func make() -> Appearance {
        let appearance = Appearance()

        // ColorPalette, FontsSwiftUI, and Images are classes, so these are
        // in-place edits of the appearance's own objects.
        let colors = appearance.colorPalette
        // Drives the send button, unread badges, links, and every other place
        // the SDK reaches for "the app's colour".
        colors.accentPrimary = .streamBot
        colors.navigationBarBackground = nil

        // Supporting SDK copy (composer placeholder, timestamps, usernames)
        // shares StreamBot's readable greys rather than the chrome ramp, which
        // in dark mode sits too close to the backdrop.
        colors.textSecondary = UIColor(Color.streamBotSecondary)
        colors.textTertiary = UIColor(Color.streamBotTertiary)
        colors.inputTextPlaceholder = UIColor(Color.streamBotTertiary)
        colors.inputTextIcon = UIColor(Color.streamBotSecondary)
        colors.chatTextSystem = UIColor(Color.streamBotSecondary)
        colors.navigationBarTintColor = .label
        colors.navigationBarSubtitle = UIColor(Color.streamBotTertiary)
        // Outlined / glass primary actions inherit this as type. Brand blue is
        // a fill, not a caption colour, so the label stays ink.
        colors.buttonPrimaryText = .label

        // Outgoing: brand blue, so the user's own side of every thread is the
        // most saturated thing on screen.
        colors.chatBackgroundOutgoing = .streamBot
        colors.chatTextOutgoing = .white
        colors.chatBorderOutgoing = .streamBot

        // Incoming: quiet surface so the bot's own card carries the colour.
        colors.chatBackgroundIncoming = UIColor.secondarySystemBackground
        colors.chatTextIncoming = UIColor.label
        colors.chatBorderIncoming = UIColor.separator

        // SecondaryLabel is too close to the dark backdrop and to the brand
        // blue. Use the same inks the rest of StreamBot uses for supporting copy.
        colors.chatTextUsername = UIColor(Color.streamBotSecondary)
        colors.chatTextTimestamp = UIColor(Color.streamBotTertiary)

        let fonts = appearance.fontsSwiftUI
        fonts.body = .system(size: 16, weight: .regular)
        fonts.bodyBold = .system(size: 16, weight: .semibold)
        fonts.subheadline = .system(size: 14, weight: .regular)
        fonts.subheadlineBold = .system(size: 14, weight: .semibold)
        fonts.headline = .system(size: 16, weight: .semibold)
        fonts.footnote = .system(size: 12, weight: .regular)

        let images = appearance.images
        images.composerSend = UIImage(systemName: "arrow.up") ?? images.composerSend

        return appearance
    }
}

// MARK: - Button style shim

/// `.glass` and `.glassProminent` are distinct concrete types, so a ternary
/// inside `buttonStyle` will not type-check. Erasing both behind one style keeps
/// call sites readable and lets prominence be data rather than a code branch.
struct StreamBotGlassButtonStyle: PrimitiveButtonStyle {
    let isProminent: Bool

    func makeBody(configuration: Configuration) -> some View {
        if isProminent {
            Button(configuration).buttonStyle(.glassProminent)
        } else {
            Button(configuration).buttonStyle(.glass)
        }
    }
}

// MARK: - Controls

/// A capsule action. The workhorse button of the app: used for Approve, Reject,
/// Run, Teach, and every sheet's confirm.
struct StreamBotActionButton: View {
    let title: String
    var symbolName: String?
    var isProminent = false
    var tint: Color?
    var size: ControlSize = .regular
    var isBusy = false
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isBusy {
                    ProgressView().controlSize(.mini)
                } else if let symbolName {
                    Image(systemName: symbolName)
                        .font(.caption.weight(.bold))
                        .contentTransition(.symbolEffect(.replace))
                        .streamBotRepeatingSymbolEffect(for: symbolName)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(labelColor)
        }
        .buttonStyle(StreamBotGlassButtonStyle(isProminent: isProminent && isEnabled))
        .buttonBorderShape(.capsule)
        .controlSize(size)
        .tint(resolvedTint)
        .opacity(isEnabled ? 1 : 0.55)
        .disabled(isBusy)
    }

    /// Prominent actions keep the fill; everything else uses label ink so a
    /// disabled Save is grey-on-glass rather than black-on-black.
    private var labelColor: Color {
        if isProminent, isEnabled { return .white }
        return .primary
    }

    /// Non-prominent controls must not inherit the app's brand tint — that is
    /// how Close and idle Save ended up as blue type on dark glass.
    private var resolvedTint: Color {
        if isProminent, isEnabled { return tint ?? .streamBot }
        return .primary
    }
}

/// A round glass control. Toolbar and composer buttons.
struct StreamBotRoundButton: View {
    let symbolName: String
    let accessibilityLabel: String
    var isProminent = false
    var tint: Color?
    var size: ControlSize = .regular
    var isActive = false
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Image(systemName: symbolName)
                .font(.system(size: 16, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .streamBotRepeatingSymbolEffect(for: symbolName)
                .symbolEffect(.variableColor.iterative, isActive: isActive)
                .foregroundStyle(iconColor)
        }
        .buttonStyle(StreamBotGlassButtonStyle(isProminent: isProminent))
        .buttonBorderShape(.circle)
        .controlSize(size)
        .tint(resolvedTint)
        .accessibilityLabel(accessibilityLabel)
    }

    /// Prominent fills are brand-coloured with a white glyph. Tinting the fill
    /// with `.primary` in dark mode made Hire a white-on-white circle.
    private var iconColor: Color {
        if isProminent { return .white }
        return tint?.streamBotOnGlass(in: colorScheme) ?? Color.primary
    }

    private var resolvedTint: Color {
        if isProminent { return tint ?? .streamBot }
        return .primary
    }
}

// MARK: - Surfaces

/// The standard glass card. Every panel in the app is one of these so corner
/// radius and inset stay consistent across the roster, run cards, and sheets.
struct StreamBotCard<Content: View>: View {
    var tint: Color?
    var cornerRadius: CGFloat = 22
    @ViewBuilder var content: Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .glassEffect(glass, in: .rect(cornerRadius: cornerRadius))
    }

    private var glass: Glass {
        guard let tint else { return .regular }
        // Lighter in the dark. A tint raises the surface's luminance, and light
        // text on a bright glass is the first thing to become hard to read — a
        // yellow-accented bot's card was the worst of them.
        return .regular.tint(tint.opacity(colorScheme == .dark ? 0.09 : 0.16))
    }
}

/// A small labelled capsule — the app's unit of metadata. Lanes, workspaces,
/// step counts, and model names are all pills.
struct StreamBotPill: View {
    let text: String
    var symbolName: String?
    var tint: Color?
    var isProminent = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 4) {
            if let symbolName {
                Image(systemName: symbolName)
                    .font(.system(size: 9, weight: .bold))
                    .streamBotRepeatingSymbolEffect(for: symbolName)
                    .foregroundStyle(iconColor)
            }
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(labelColor)
        }
        .padding(.horizontal, 9)
        .frame(height: 24)
        .glassEffect(glass, in: .capsule)
    }

    /// Icons may carry the accent; the word is always ink, never a dark blue
    /// fill used as type — including on prominent pills, where the tint lives
    /// in the glass rather than the letters.
    private var iconColor: Color {
        tint?.streamBotOnGlass(in: colorScheme) ?? .streamBotSecondary
    }

    private var labelColor: Color {
        tint == nil ? .streamBotSecondary : .primary
    }

    private var glass: Glass {
        guard isProminent, let tint else { return .regular }
        return .regular.tint(tint.opacity(colorScheme == .dark ? 0.28 : 0.22))
    }
}

/// Empty state. Says what to do next rather than what is missing.
struct StreamBotEmptyState: View {
    let symbolName: String
    let title: String
    let detail: String
    var action: (title: String, handler: () -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbolName)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.streamBotSecondary)
                .streamBotRepeatingSymbolEffect(for: symbolName)
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.streamBotSecondary)
                .multilineTextAlignment(.center)
            if let action {
                StreamBotActionButton(
                    title: action.title,
                    symbolName: "plus",
                    isProminent: true,
                    action: action.handler
                )
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 24)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
        .padding(.horizontal, 20)
    }
}

// MARK: - Bot identity

/// A teammate's face. The symbol plus its accent is the bot's identity
/// everywhere — roster, thread row, message bubble, run card — so it is one
/// view rather than a repeated `ZStack`.
struct StreamBotAvatar: View {
    let symbolName: String
    let accent: Color
    var size: CGFloat = 40
    /// Draws the pulsing ring that marks a bot as mid-run.
    var isWorking = false

    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(accent.gradient.opacity(0.9))
            Image(systemName: symbolName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)
                .streamBotRepeatingSymbolEffect(for: symbolName)
            if isWorking {
                Circle()
                    .stroke(accent.opacity(0.55), lineWidth: 2)
                    .scaleEffect(pulse ? 1.28 : 1.02)
                    .opacity(pulse ? 0 : 1)
            }
        }
        .frame(width: size, height: size)
        .onChange(of: isWorking) { _, working in
            guard working else {
                pulse = false
                return
            }
            withAnimation(.easeOut(duration: 1.3).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Repeating symbol motion

extension View {
    /// The looping SF Symbol animation that best matches `symbolName`.
    ///
    /// Picked from the SF Symbols animation set — bounce, scale, wiggle, rotate,
    /// breathe, pulse, and variable color — so a chart walks its layers, a bug
    /// wiggles, a heart breathes, and a mic pulses, rather than every icon
    /// sharing one effect.
    @ViewBuilder
    func streamBotRepeatingSymbolEffect(
        for symbolName: String,
        isActive: Bool = true
    ) -> some View {
        switch StreamBotSymbolMotion.bestFit(for: symbolName) {
        case .bounce:
            symbolEffect(.bounce, options: .repeat(.periodic(delay: 1.5)), isActive: isActive)
        case .bounceDown:
            symbolEffect(.bounce.down, options: .repeat(.periodic(delay: 1.5)), isActive: isActive)
        case .scale:
            symbolEffect(.scale, options: .repeat(.periodic(delay: 1.6)), isActive: isActive)
        case .wiggle:
            symbolEffect(.wiggle, options: .repeat(.periodic(delay: 1.4)), isActive: isActive)
        case .wiggleRight:
            symbolEffect(.wiggle.right, options: .repeat(.periodic(delay: 1.4)), isActive: isActive)
        case .rotate:
            symbolEffect(.rotate.clockwise, options: .repeat(.continuous), isActive: isActive)
        case .breathe:
            symbolEffect(.breathe, options: .repeat(.continuous), isActive: isActive)
        case .pulse:
            symbolEffect(.pulse, options: .repeat(.continuous), isActive: isActive)
        case .variableColor:
            symbolRenderingMode(.hierarchical)
                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: isActive)
        }
    }
}

/// Which repeating SF Symbol animation to play for a given system image.
private enum StreamBotSymbolMotion {
    case bounce, bounceDown, scale, wiggle, wiggleRight, rotate
    case breathe, pulse, variableColor

    static func bestFit(for symbolName: String) -> Self {
        switch symbolName {
        // Layered / sequential symbols — variable color walks the layers.
        // Charts belong here rather than Draw On: a repeating draw-on starts
        // each cycle undrawn, so Ada's avatar would vanish on the thread list.
        case "person.3.sequence",
             "waveform",
             "chart.bar.fill",
             "chart.line.uptrend.xyaxis",
             "checklist":
            .variableColor

        // Search / inspect — scale reads as "looking closer".
        case "doc.text.magnifyingglass",
             "text.magnifyingglass",
             "binoculars":
            .scale

        // Incoming / adding / success — bounce.
        case "person.badge.plus",
             "graduationcap",
             "graduationcap.fill",
             "checkmark",
             "checkmark.circle.fill",
             "checkmark.seal.fill",
             "plus",
             "play.fill",
             "calendar",
             "bell.badge",
             "hand.tap":
            .bounce

        case "tray.and.arrow.down.fill":
            .bounceDown

        // Conversation, alerts, bugs, cards, hands — wiggle.
        case "bubble.left.and.text.bubble.right",
             "ladybug",
             "ladybug.fill",
             "tray.full",
             "creditcard",
             "hand.raised",
             "hand.raised.fill",
             "envelope.fill",
             "exclamationmark.triangle.fill",
             "exclamationmark.circle.fill",
             "slider.horizontal.3",
             "xmark",
             "xmark.seal.fill",
             "arrow.uturn.left",
             "puzzlepiece.extension",
             "person.crop.rectangle.stack.fill",
             "person.text.rectangle.fill",
             "person.text.rectangle",
             "person.2",
             "building.2.fill",
             "megaphone.fill",
             "speedometer":
            .wiggle

        case "arrow.right":
            .wiggleRight

        // Things that spin — gears, retry, globe.
        case "gearshape.2.fill",
             "arrow.clockwise",
             "globe",
             "person.2.badge.gearshape",
             "cpu",
             "desktopcomputer",
             "gearshape":
            .rotate

        // Live / energy / waiting dots.
        case "bolt.fill",
             "mic.fill",
             "stop.fill",
             "circle.dotted",
             "minus.circle":
            .pulse

        // Living / idle presence.
        case "heart.text.square",
             "sparkles",
             "wand.and.stars",
             "pause.circle.fill",
             "brain",
             "doc.text.fill":
            .breathe

        default:
            .breathe
        }
    }
}

/// A tiny status light. Green while a bot is working, amber when it is waiting
/// on the user, clear otherwise.
///
/// The case set is named `Activity` rather than `State` on purpose: a nested
/// `State` inside a `View` shadows `SwiftUI.State` and quietly breaks
/// `@State` declarations in the same type.
struct StreamBotStatusDot: View {
    enum Activity { case idle, working, waiting, failed }

    let activity: Activity
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(.background, lineWidth: 1.5)
            )
            .opacity(activity == .idle ? 0 : 1)
    }

    private var color: Color {
        switch activity {
        case .idle: .clear
        case .working: .green
        case .waiting: .orange
        case .failed: .red
        }
    }
}

// MARK: - Progress

/// A thin glass track. Run progress and model download progress.
struct StreamBotProgressTrack: View {
    let fraction: Double
    var tint: Color = .streamBot
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(tint.gradient)
                    .frame(width: max(height, proxy.size.width * fraction.clampedUnit))
            }
        }
        .frame(height: height)
        .animation(.smooth(duration: 0.3), value: fraction)
        .accessibilityValue("\(Int(fraction.clampedUnit * 100)) percent")
    }
}

// MARK: - Text

/// Text that grows as tokens land, without re-animating what is already there.
///
/// Animating the `Text` itself cross-fades the whole paragraph on every token,
/// which is the opposite of the "words appear as they are written" feel. The
/// string updates with no animation on the glyphs; only the container's height
/// change is animated.
struct StreamBotStreamingText: View {
    let text: String
    var font: Font = .system(size: 16)
    var showsCaret = false

    var body: some View {
        Group {
            if showsCaret {
                Text(text) + Text(" ▍").foregroundColor(Color.streamBotSecondary)
            } else {
                Text(text)
            }
        }
        .font(font)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(nil, value: text)
    }
}

/// Three dots that breathe while a bot is thinking but has produced nothing yet.
struct StreamBotThinkingDots: View {
    var tint: Color = .streamBotSecondary
    @Environment(\.colorScheme) private var colorScheme
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(tint.streamBotOnGlass(in: colorScheme))
                    .frame(width: 5, height: 5)
                    .scaleEffect(animating ? 1 : 0.5)
                    .opacity(animating ? 1 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.55)
                            .repeatForever()
                            .delay(Double(index) * 0.16),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
        .accessibilityLabel("Thinking")
    }
}

// MARK: - Waveform

/// Live dictation meter. Driven from the mic tap's RMS level, so it is flat in a
/// quiet room and blooms when somebody speaks — visible proof the microphone is
/// actually being heard before any text has been transcribed.
struct StreamBotWaveform: View {
    let level: Float
    var barCount = 32
    var tint: Color = .streamBot
    var maxHeight: CGFloat = 30

    @State private var history: [CGFloat] = []

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(history.enumerated()), id: \.offset) { _, value in
                Capsule()
                    .fill(tint.opacity(0.3 + value * 0.7))
                    .frame(width: 3, height: max(3, value * maxHeight))
            }
        }
        .frame(height: maxHeight)
        .onAppear {
            if history.isEmpty {
                history = Array(repeating: 0.05, count: barCount)
            }
        }
        .onChange(of: level) { _, newValue in
            withAnimation(.easeOut(duration: 0.1)) {
                if !history.isEmpty { history.removeFirst() }
                history.append(CGFloat(min(max(newValue, 0.04), 1)))
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Backdrop

/// The quiet gradient behind the roster and routine screens. Two out-of-phase
/// radial gradients read as depth behind the glass for the cost of one animated
/// `UnitPoint` per layer.
struct StreamBotBackdrop: View {
    var tint: Color = .streamBot
    @State private var drift = false

    var body: some View {
        ZStack {
            Color(.systemBackground)
            RadialGradient(
                colors: [tint.opacity(0.18), .clear],
                center: drift ? UnitPoint(x: 0.12, y: 0.04) : UnitPoint(x: 0.38, y: 0.18),
                startRadius: 8,
                endRadius: 520
            )
            RadialGradient(
                colors: [Color.streamBot.opacity(0.08), .clear],
                center: drift ? UnitPoint(x: 0.92, y: 0.82) : UnitPoint(x: 0.68, y: 0.96),
                startRadius: 8,
                endRadius: 480
            )
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 16).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }
}

// MARK: - Utilities

extension Double {
    var clampedUnit: Double { Swift.min(Swift.max(self, 0), 1) }
}

// MARK: - Editorial chrome

/// Small-caps section label used above a group of cards. Tracking and case do
/// the hierarchy work so the title of the card itself can stay sentence case.
struct StreamBotSectionLabel: View {
    let text: String
    var symbol: String?

    var body: some View {
        HStack(spacing: 6) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.caption2.weight(.bold))
                    .streamBotRepeatingSymbolEffect(for: symbol)
            }
            Text(text)
                .font(.caption2.weight(.semibold))
                .tracking(1.1)
                .textCase(.uppercase)
        }
        .foregroundStyle(.streamBotSecondary)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Screen intro. Title2 + a one-line brief, so Models / Team / Settings open
/// like a designed product rather than a list that starts at the first card.
struct StreamBotEditorialHeader: View {
    let eyebrow: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow)
                .font(.caption2.weight(.semibold))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(.streamBotSecondary)
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.streamBotSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
    }
}

/// A compact status chip for "N working" / "N waiting".
struct StreamBotStatChip: View {
    let value: Int
    let label: String
    var tint: Color = .streamBot
    var symbolName: String?

    var body: some View {
        HStack(spacing: 6) {
            if let symbolName {
                Image(systemName: symbolName)
                    .font(.caption.weight(.bold))
                    .streamBotRepeatingSymbolEffect(for: symbolName)
            }
            Text("\(value)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.streamBotSecondary)
        }
        .streamBotAccentText(value > 0 ? tint : .streamBotSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(value > 0 ? .regular.tint(tint.opacity(0.16)) : .regular, in: .capsule)
    }
}

extension View {
    /// Dismisses the keyboard on taps no control claimed. A plain (non
    /// simultaneous) tap on purpose: SwiftUI gives child gestures priority, so
    /// buttons still fire and moving between text fields still moves focus.
    func streamBotDismissesKeyboardOnTap() -> some View {
        onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
    }
}
#endif
