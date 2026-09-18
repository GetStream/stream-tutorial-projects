import SwiftUI

/// Small, consistent Liquid Glass vocabulary for the app.
///
/// The SDK ships its own `LiquidGlassStyles` for the composer chrome; these
/// helpers cover the app-owned surfaces (sidebar rows, pills, hero cards) so
/// everything shares one look.
extension View {
    /// Regular glass card with a subtle hairline. Use for sheets, rows, bubbles.
    func auroraGlass(
        cornerRadius: CGFloat = 22,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        modifier(AuroraGlassModifier(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), tint: tint, interactive: interactive))
    }

    /// Capsule glass - chips, badges, toolbar pills.
    func auroraGlassCapsule(tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(AuroraGlassModifier(shape: Capsule(), tint: tint, interactive: interactive))
    }

    /// Circular glass - icon buttons and avatars.
    func auroraGlassCircle(tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(AuroraGlassModifier(shape: Circle(), tint: tint, interactive: interactive))
    }
}

struct AuroraGlassModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let tint: Color?
    let interactive: Bool

    func body(content: Content) -> some View {
        content
            .contentShape(shape)
            .glassEffect(glass, in: shape)
            .overlay(shape.strokeBorder(.white.opacity(0.35), lineWidth: 0.6))
    }

    private var glass: Glass {
        var glass: Glass = .regular
        if let tint { glass = glass.tint(tint) }
        if interactive { glass = glass.interactive() }
        return glass
    }
}

/// Icon-only glass button used across toolbars and the composer.
struct GlassIconButton: View {
    let systemName: String
    var tint: Color? = nil
    var size: CGFloat = 40
    var accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(Aurora.textPrimary)
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .auroraGlassCircle(tint: tint, interactive: true)
        .accessibilityLabel(accessibilityLabel)
    }
}
