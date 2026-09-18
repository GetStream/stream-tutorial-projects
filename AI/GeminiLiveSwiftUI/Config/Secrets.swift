import Foundation

/// Local-only secrets. This file is gitignored; recreate it on a new machine from
/// the `GEMINI_API_KEY` export in ~/.zprofile (see "Run it" in StreamLive.md).
nonisolated enum Secrets {
    static let geminiAPIKey = "YOUR_GEMINI_API_KEY"
}
