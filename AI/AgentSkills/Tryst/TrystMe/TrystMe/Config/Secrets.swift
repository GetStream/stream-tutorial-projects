//
//  Secrets.swift
//  TrystMe
//
//  Stream credentials and demo user tokens.
//
//  NOTE: For a real product, tokens come from your backend. These never-expiring
//  demo tokens were generated with the Stream CLI for local development only.
//  The API *secret* is never embedded here — only the public API key and user tokens.
//

import Foundation

/// A user's tokens for the two Stream apps that power TrystMe.
/// Chat + Video share one app; Feeds runs on its own app (Feeds V3).
struct TokenPair {
    let chat: String   // valid for both Chat and Video (same app/key)
    let feeds: String
}

enum Secrets {
    /// Chat + Video app key (one Stream project covers both products).
    static let chatVideoAPIKey = "hd8szvscpxvd"

    /// Feeds V3 app key (separate Stream project).
    static let feedsAPIKey = "7hx4yyzjbtcm"

    /// Custom channel type configured with circumvention moderation + blocklist.
    static let channelType = "tryst"

    /// Per-user demo tokens for each Stream app.
    static let tokens: [String: TokenPair] = [
        "alex_rivera": TokenPair(chat: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiYWxleF9yaXZlcmEifQ.kMcWANNk7IQLj2zRgx4LXDzf-Yj4ZsrOeumOiD8AchE", feeds: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiYWxleF9yaXZlcmEifQ.gTTM-6j1_AUApwz4Gd9LMyB39RgVfhyDPCnGcfML4KY"),
        "sophia_lee": TokenPair(chat: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoic29waGlhX2xlZSJ9.ZjD_RUj5ClaxMWoC10z8LVS1D8v3H9ee3kuqcDxPnnw", feeds: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoic29waGlhX2xlZSJ9.gyZI91jgOlslaymnHV1VkHNCRK-AGF5IDXIFvU42rNU"),
        "mia_chen": TokenPair(chat: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoibWlhX2NoZW4ifQ.GGDfMtxzpqjHx800AGPghJ5U_KsOk0SDyP8UW4muVrk", feeds: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoibWlhX2NoZW4ifQ.3Lg-IBilLwjQShEoz0vynEYpH2ym1kAl7iBeYVo_IxM"),
        "emma_johnson": TokenPair(chat: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiZW1tYV9qb2huc29uIn0.VA7i29oWU5Thff1ZdkVYZQv6Oe5EypSLpCrQ589pkgk", feeds: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiZW1tYV9qb2huc29uIn0.SgjFpyRoDlMxphHevluoC61OOhXXJYsF3dryuxEjcAI"),
        "olivia_brown": TokenPair(chat: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoib2xpdmlhX2Jyb3duIn0.Y_Hcp0qG6odkh2n5qC6r_r88-obDM_O_khtwR6H4K7A", feeds: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoib2xpdmlhX2Jyb3duIn0.04P6v9fHuwz8TKKcKiFI2TsxBK_5lhEsVIqjRkO5eXA"),
        "ava_martinez": TokenPair(chat: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiYXZhX21hcnRpbmV6In0.9ZPt-hu3VAIotAD-uYCm3H5wwFrs_mGK-9vXz5FmHwM", feeds: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiYXZhX21hcnRpbmV6In0.10_aWJwxaAonh4Gt2rwLmsb4Rxc7Qb1Q90Rc2P75Xmw"),
        "isabella_garcia": TokenPair(chat: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiaXNhYmVsbGFfZ2FyY2lhIn0.iXYwWwgK8mI4HT891YTAlr8WkHNGBFnHiPfxEHox-ak", feeds: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiaXNhYmVsbGFfZ2FyY2lhIn0.qZFR-hvfgevU5kRuJiS0TNX2CjCUoWtADOr2vKZPyX8"),
        "liam_smith": TokenPair(chat: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoibGlhbV9zbWl0aCJ9.rkmJ2wMVFV-f0IRPzd_fhoNUSru5OLlaWoT0JlgXuEs", feeds: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoibGlhbV9zbWl0aCJ9.FuNS6BNKx2YsV8pUOeDRvvb-n1G5G68h0EZByMl740Y"),
        "noah_williams": TokenPair(chat: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoibm9haF93aWxsaWFtcyJ9.C1y9PGeBROxTRLKIPuDEaPsZNM1lIYZ3mItsp3enKDQ", feeds: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoibm9haF93aWxsaWFtcyJ9.8-B-B6D28tdDW-dlVQoBF6s9_oC1vEVsExvOqTGKAa0"),
        "ethan_davis": TokenPair(chat: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiZXRoYW5fZGF2aXMifQ.H0roLA86NaY6EvxXnqURxuNB_E-yu8EdAP6HeuFwmiM", feeds: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiZXRoYW5fZGF2aXMifQ.r9YFewzmJW9k0LNHWSiOIDVpAwd4GHo6IzSAPs2WA30"),
        "lucas_wilson": TokenPair(chat: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoibHVjYXNfd2lsc29uIn0.1qsYxlJlDdO7mZNR16r82xaAV7BrKA0qZSsQWXu5DhI", feeds: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoibHVjYXNfd2lsc29uIn0.Olceudx_u5IHl-qEixjS1AhFasyPRndj3KKADNm_75A"),
        "mason_taylor": TokenPair(chat: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoibWFzb25fdGF5bG9yIn0.-jFe1tFGkC1xtyORuzPArINdbBDgftHLPdU7uiHUZbk", feeds: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoibWFzb25fdGF5bG9yIn0.GoW_VmpLSwT-n4t_mqJeQnNn2gb7CvPBxLPz6HiKOoo"),
        "zoe_anderson": TokenPair(chat: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiem9lX2FuZGVyc29uIn0.gmJ9sW-JfUTCPJp_9t5vXf6fFP10AUReHH0sdIJvcZI", feeds: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiem9lX2FuZGVyc29uIn0.MTP97bXIXPc5AerQA4MpAyFwv6C1ceExNVXSY9uk3zQ"),
    ]

    static func token(for userId: String) -> TokenPair? { tokens[userId] }
}
