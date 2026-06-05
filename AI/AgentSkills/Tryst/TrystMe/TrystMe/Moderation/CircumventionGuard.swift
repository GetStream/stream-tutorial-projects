//
//  CircumventionGuard.swift
//  TrystMe
//
//  Client-side circumvention / PII detector. Catches attempts to move users
//  off-platform or solicit money/personal data BEFORE a message is sent, so the
//  message can be held in a "pending review" state. This complements the
//  server-side blocklist + automod configured on the `tryst` channel type.
//  Neutral (no Stream imports).
//

import Foundation

struct ModerationFinding: Identifiable, Hashable {
    let id = UUID()
    let category: String
    let snippet: String
}

enum CircumventionGuard {
    private static let patterns: [(category: String, regex: String)] = [
        ("Phone number", #"(?:\+?\d[\s\-.]?){7,}"#),
        ("Email address", #"[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}"#),
        ("Credit card", #"\b(?:\d[ \-]*?){13,16}\b"#),
        ("Payment app", #"\b(venmo|cash\s?app|zelle|paypal|bitcoin|btc|gift\s?card|wire\s?transfer|western\s?union|money\s?gram)\b"#),
        ("Off-platform contact", #"\b(whats\s?app|telegram|snapchat|snap|kik|wechat|insta(gram)?|dm me on|text me|call me|my number|hit me up on)\b"#),
        ("External link", #"\b(?:https?://|www\.)\S+"#),
    ]

    /// Returns all moderation findings for the given text.
    static func scan(_ text: String) -> [ModerationFinding] {
        var findings: [ModerationFinding] = []
        for (category, pattern) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                guard let match, let r = Range(match.range, in: text) else { return }
                let snippet = String(text[r]).trimmingCharacters(in: .whitespaces)
                // Avoid false positives on tiny digit groups.
                if category == "Phone number" && snippet.filter(\.isNumber).count < 7 { return }
                if category == "Credit card" && snippet.filter(\.isNumber).count < 13 { return }
                findings.append(ModerationFinding(category: category, snippet: snippet))
            }
        }
        return findings
    }

    static func isClean(_ text: String) -> Bool { scan(text).isEmpty }
}
