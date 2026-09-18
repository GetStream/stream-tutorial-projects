import SwiftUI

/// Full-screen backdrop that recreates the reference artwork: a periwinkle
/// field with a soft white core glow and a faint prismatic halo. Everything
/// glassy in the app sits on top of this so Liquid Glass has color to refract.
struct AuroraBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var drift = false

    /// Attach with `.background(AuroraBackground())` - the view takes exactly the
    /// size it is given (all decoration is overlaid) and `background` already
    /// extends into the safe area, so it never disturbs sibling layout.
    var body: some View {
        field
            // Corner haze for depth.
            .overlay {
                RadialGradient(
                    colors: [Aurora.haloSky.opacity(0.45), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 500
                )
            }
            .overlay {
                RadialGradient(
                    colors: [Aurora.periwinkle500.opacity(colorScheme == .dark ? 0.6 : 0.55), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 600
                )
            }
            // Prismatic halo ring.
            .overlay {
                Circle()
                    .strokeBorder(Aurora.prism, lineWidth: 90)
                    .frame(width: 720, height: 720)
                    .blur(radius: 70)
                    .opacity(colorScheme == .dark ? 0.16 : 0.32)
                    .offset(y: drift ? -40 : -20)
                    .blendMode(.plusLighter)
            }
            // Core glow - slowly breathes so the glass above feels alive.
            .overlay {
                RadialGradient(
                    stops: [
                        .init(color: Aurora.glow.opacity(colorScheme == .dark ? 0.28 : 0.85), location: 0),
                        .init(color: Aurora.glow.opacity(colorScheme == .dark ? 0.12 : 0.35), location: 0.45),
                        .init(color: .clear, location: 1)
                    ],
                    center: .init(x: 0.5, y: drift ? 0.4 : 0.36),
                    startRadius: 0,
                    endRadius: 230
                )
            }
            .clipped()
            .animation(.easeInOut(duration: 9).repeatForever(autoreverses: true), value: drift)
            .onAppear { drift = true }
    }

    private var field: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Aurora.night100, Aurora.night300, Aurora.night500]
                : [Aurora.periwinkle100, Aurora.periwinkle300, Aurora.periwinkle500],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// The glowing orb from the artwork, used as the app mark on the welcome screen
/// and as the assistant avatar.
struct AuroraOrb: View {
    var size: CGFloat = 120
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Aurora.prism)
                .blur(radius: size * 0.18)
                .opacity(0.8)
                .scaleEffect(pulse ? 1.08 : 0.96)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, .white.opacity(0.85), Aurora.periwinkle300.opacity(0.4)],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.55
                    )
                )
                .overlay(
                    Circle().strokeBorder(.white.opacity(0.9), lineWidth: 1.5)
                )
                .shadow(color: .white.opacity(0.7), radius: size * 0.25)

            Image(systemName: "sparkle")
                .font(.system(size: size * 0.34, weight: .medium))
                .foregroundStyle(Aurora.periwinkle600)
                .symbolEffect(.pulse, options: .repeating, isActive: true)
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
        .accessibilityHidden(true)
    }
}

#Preview("Background") {
    AuroraOrb()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AuroraBackground())
}
