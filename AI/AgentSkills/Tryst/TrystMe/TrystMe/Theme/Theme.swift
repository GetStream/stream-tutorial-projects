//
//  Theme.swift
//  TrystMe
//
//  Brand colors, gradients and shared UI helpers.
//

import SwiftUI

enum Brand {
    static let pink = Color(red: 0.99, green: 0.27, blue: 0.45)     // #FD4574
    static let coral = Color(red: 1.0, green: 0.45, blue: 0.42)     // #FF736B
    static let orange = Color(red: 1.0, green: 0.58, blue: 0.31)    // #FF944F
    static let purple = Color(red: 0.62, green: 0.30, blue: 0.93)   // #9E4DED
    static let ink = Color(red: 0.11, green: 0.10, blue: 0.16)

    static var primaryGradient: LinearGradient {
        LinearGradient(colors: [pink, orange], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var loveGradient: LinearGradient {
        LinearGradient(colors: [pink, purple], startPoint: .top, endPoint: .bottom)
    }

    static var likeGradient: LinearGradient {
        LinearGradient(colors: [Color.green, Color.teal], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension View {
    /// Soft elevated card surface used across the app.
    func cardSurface(cornerRadius: CGFloat = 24) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
    }

    func brandFilledButton() -> some View {
        font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Brand.primaryGradient, in: Capsule())
            .shadow(color: Brand.pink.opacity(0.35), radius: 12, y: 6)
    }
}

/// A tag pill used to display interests.
struct InterestPill: View {
    let text: String
    var filled: Bool = false

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(filled ? .white : Brand.pink)
            .background {
                if filled {
                    Capsule().fill(Brand.primaryGradient)
                } else {
                    Capsule().fill(Brand.pink.opacity(0.12))
                }
            }
    }
}
