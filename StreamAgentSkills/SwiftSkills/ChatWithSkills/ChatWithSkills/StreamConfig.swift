//
//  StreamConfig.swift
//  ChatWithSkills
//
//  Centralized Stream Chat configuration for the demo app.
//  The API secret never lives in app code — tokens were minted by the
//  Stream CLI (`stream token <user_id>`) and bundled here purely for the
//  out-of-the-box demo experience. Swap to a backend-issued
//  `TokenProvider` when you wire this into a real auth system.
//

import Foundation

enum StreamConfig {
    /// Stream Chat API key for this app.
    /// Find or regenerate at https://dashboard.getstream.io
    static let apiKey = "hd8szvscpxvd"

    /// Demo users seeded into the Stream backend.
    /// All tokens are non-expiring JWTs generated via `stream token <user_id>`.
    static let demoUsers: [DemoUser] = [
        DemoUser(
            id: "amos",
            name: "Amos",
            imageURL: URL(string: "https://i.pravatar.cc/200?u=amos"),
            token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiYW1vcyJ9.fTdyTe6edyGaQifbhZ_EM_ELpmEAMD6-DVw98Iq_3x8"
        ),
        DemoUser(
            id: "alice",
            name: "Alice Johnson",
            imageURL: URL(string: "https://i.pravatar.cc/200?u=alice"),
            token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiYWxpY2UifQ.sfyLiwhlCbjKu5gfJOxYxObU-UVazO1YKvc0xeV9su0"
        ),
        DemoUser(
            id: "bob",
            name: "Bob Martinez",
            imageURL: URL(string: "https://i.pravatar.cc/200?u=bob"),
            token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiYm9iIn0._MF_Oshp05Rd9FxLXk2e4qqMzkSV7FmwgAgcquQJCxg"
        ),
        DemoUser(
            id: "carol",
            name: "Carol Smith",
            imageURL: URL(string: "https://i.pravatar.cc/200?u=carol"),
            token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiY2Fyb2wifQ.c7ZDX2c3tMF39u_krBGApjByqnDKDGqA0Z4OBvcKxoY"
        ),
        DemoUser(
            id: "dave",
            name: "Dave Chen",
            imageURL: URL(string: "https://i.pravatar.cc/200?u=dave"),
            token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiZGF2ZSJ9.-bIS13zP3w_gWrZ0L9aOhs4gBBjqK5Eq4BsxPA0FjKQ"
        ),
        DemoUser(
            id: "eve",
            name: "Eve Patel",
            imageURL: URL(string: "https://i.pravatar.cc/200?u=eve"),
            token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiZXZlIn0.mSl31TaRHILy3iBjBr-_fHCmDgy2N7Q7HF6tF1H9CCE"
        )
    ]
}

struct DemoUser: Identifiable, Hashable {
    let id: String
    let name: String
    let imageURL: URL?
    let token: String
}
