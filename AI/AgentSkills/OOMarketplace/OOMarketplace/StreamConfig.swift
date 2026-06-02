//
//  StreamConfig.swift
//  OOMarketplace
//

import Foundation

/// Stream credentials and the current demo user.
///
/// API keys come from the dashboard; user tokens are minted via the Stream CLI
/// (`stream token seller_amos`). The API secret is NEVER embedded - it stays
/// server-side / inside the CLI only.
///
/// Chat and Video share one Stream app (`hd8szvscpxvd`); Stream Feeds v3 lives on a
/// separate app (`7hx4yyzjbtcm`) and therefore needs its own API key + user token,
/// because a token is only valid for the app whose secret signed it.
enum StreamConfig {
    // MARK: - Chat + Video (shared app)
    static let apiKey = "hd8szvscpxvd"

    static let currentUserId   = "seller_amos"
    static let currentUserName = "Amos (Seller)"
    static let currentUserImage = URL(string: "https://i.pravatar.cc/300?u=seller_amos")

    /// Token for `seller_amos`, valid for the Chat + Video app (`hd8szvscpxvd`).
    static let userToken =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoic2VsbGVyX2Ftb3MifQ.-TZvwOoOBdWs1QwDCUNaZ0Rh2_AD-RCaF6yqbG1Gnv0"

    // MARK: - Feeds v3 (separate app)
    static let feedsApiKey = "7hx4yyzjbtcm"

    /// Token for `seller_amos`, valid for the Feeds v3 app (`7hx4yyzjbtcm`).
    static let feedsUserToken =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoic2VsbGVyX2Ftb3MifQ.UeaEzx8sBNPE75zGwDPItBT5zbcHnCxQvV0ff8Ts09g"

    /// Demo marketplace peers the seller can already chat with.
    /// Channel IDs of the form `listing-<slug>` were pre-seeded via the Stream CLI.
    static let knownPeers: [DemoUser] = [
        .init(id: "buyer_jane",  name: "Jane Park"),
        .init(id: "buyer_max",   name: "Max Lee"),
        .init(id: "buyer_zoe",   name: "Zoe Singh"),
        .init(id: "seller_kira", name: "Kira Vintage"),
        .init(id: "seller_otto", name: "Otto Audio")
    ]
}

struct DemoUser: Identifiable, Hashable {
    let id: String
    let name: String
    var imageURL: URL? { URL(string: "https://i.pravatar.cc/300?u=\(id)") }
}
