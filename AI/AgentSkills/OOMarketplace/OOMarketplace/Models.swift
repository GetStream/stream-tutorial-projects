//
//  Models.swift
//  OOMarketplace
//
//  Plain domain types - no Stream imports. Everything in this file can be referenced
//  from any other file (Chat, Video, Feeds, plain SwiftUI) without collision risk.
//

import Combine
import Foundation
import SwiftUI

// MARK: - Listing

struct Listing: Identifiable, Hashable {
    let id: String
    var title: String
    var subtitle: String
    var price: Double
    var imageURL: URL?
    var category: Category
    var sellerId: String
    var sellerName: String
    /// Channel ID seeded via the Stream CLI (`messaging:listing-<slug>`).
    /// Used to open the buyer-seller chat with full listing context.
    var channelId: String?
    var isDailyDeal: Bool = false
    var dealEndsAt: Date? = nil
}

extension Listing {
    enum Category: String, CaseIterable, Hashable {
        case audio = "Audio"
        case fashion = "Fashion"
        case electronics = "Electronics"
        case sports = "Sports"
        case home = "Home"
        case books = "Books"
        case other = "Other"

        var icon: String {
            switch self {
            case .audio: return "music.note"
            case .fashion: return "tshirt"
            case .electronics: return "iphone"
            case .sports: return "bicycle"
            case .home: return "house"
            case .books: return "book"
            case .other: return "tag"
            }
        }
    }
}

// MARK: - Order

struct Order: Identifiable, Hashable {
    enum Status: String {
        case placed = "Placed"
        case shipped = "Shipped"
        case outForDelivery = "Out for delivery"
        case delivered = "Delivered"

        var icon: String {
            switch self {
            case .placed: return "creditcard.fill"
            case .shipped: return "shippingbox.fill"
            case .outForDelivery: return "bicycle"
            case .delivered: return "checkmark.seal.fill"
            }
        }
    }

    let id: String
    var listing: Listing
    var status: Status
    var placedAt: Date
}

// MARK: - Repository (in-memory demo data)

@MainActor
final class MarketplaceRepository: ObservableObject {
    static let shared = MarketplaceRepository()

    @Published private(set) var listings: [Listing]
    @Published var orders: [Order] = []
    @Published var favorites: Set<String> = []

    private init() {
        let now = Date()
        listings = [
            Listing(
                id: "listing-001",
                title: "Mid-century Vinyl Record Player",
                subtitle: "Walnut veneer • All original • Tested",
                price: 189,
                imageURL: URL(string: "https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=600&h=600&fit=crop&fm=jpg&q=80"),
                category: .audio,
                sellerId: "seller_amos",
                sellerName: "Amos",
                channelId: "listing-vinyl-recordplayer",
                isDailyDeal: true,
                dealEndsAt: now.addingTimeInterval(60 * 60 * 6)
            ),
            Listing(
                id: "listing-002",
                title: "Vintage Brown Leather Jacket",
                subtitle: "Size M • Italian leather • Light wear",
                price: 75,
                imageURL: URL(string: "https://images.unsplash.com/photo-1551028719-00167b16eac5?w=600&h=600&fit=crop&fm=jpg&q=80"),
                category: .fashion,
                sellerId: "seller_kira",
                sellerName: "Kira",
                channelId: "listing-leather-jacket"
            ),
            Listing(
                id: "listing-003",
                title: "AirPods Pro 2 with MagSafe",
                subtitle: "Sealed in box • Apple warranty 9mo",
                price: 159,
                imageURL: URL(string: "https://images.unsplash.com/photo-1606220588913-b3aacb4d2f46?w=600&h=600&fit=crop&fm=jpg&q=80"),
                category: .electronics,
                sellerId: "seller_otto",
                sellerName: "Otto",
                channelId: "listing-airpods",
                isDailyDeal: true,
                dealEndsAt: now.addingTimeInterval(60 * 60 * 12)
            ),
            Listing(
                id: "listing-004",
                title: "Carbon Fiber Road Bike (54cm)",
                subtitle: "Shimano Ultegra Di2 • New tires",
                price: 820,
                imageURL: URL(string: "https://images.unsplash.com/photo-1485965120184-e220f721d03e?w=600&h=600&fit=crop&fm=jpg&q=80"),
                category: .sports,
                sellerId: "seller_amos",
                sellerName: "Amos",
                channelId: "listing-roadbike"
            ),
            Listing(
                id: "listing-005",
                title: "Linen Sofa Cover - Beige",
                subtitle: "Fits 3-seater • Washed once",
                price: 35,
                imageURL: URL(string: "https://images.unsplash.com/photo-1567016432779-094069958ea5?w=600&h=600&fit=crop&fm=jpg&q=80"),
                category: .home,
                sellerId: "seller_kira",
                sellerName: "Kira"
            ),
            Listing(
                id: "listing-006",
                title: "Boxset: Sci-fi Classics",
                subtitle: "12 hardcovers • Mint condition",
                price: 60,
                imageURL: URL(string: "https://images.unsplash.com/photo-1532012197267-da84d127e765?w=600&h=600&fit=crop&fm=jpg&q=80"),
                category: .books,
                sellerId: "seller_otto",
                sellerName: "Otto"
            )
        ]

        // Seed a couple of in-flight orders so the demo "Delivery update" push has context.
        orders = [
            Order(id: "order-1", listing: listings[2], status: .outForDelivery, placedAt: now.addingTimeInterval(-3600 * 28)),
            Order(id: "order-2", listing: listings[0], status: .shipped,        placedAt: now.addingTimeInterval(-3600 * 6))
        ]
    }

    func toggleFavorite(_ listingId: String) {
        if favorites.contains(listingId) {
            favorites.remove(listingId)
        } else {
            favorites.insert(listingId)
        }
    }

    func isFavorite(_ listingId: String) -> Bool { favorites.contains(listingId) }

    func listing(for id: String) -> Listing? { listings.first { $0.id == id } }

    func listing(forChannelId channelId: String) -> Listing? {
        listings.first { $0.channelId == channelId }
    }

    func addListing(_ listing: Listing) {
        listings.insert(listing, at: 0)
    }

    func dailyDeals() -> [Listing] { listings.filter { $0.isDailyDeal } }
}

// MARK: - App-wide cross-feature events

/// Bridges actions between the file-isolated Stream services without leaking SDK types
/// across import boundaries.
enum AppEvents {
    static let openChat   = Notification.Name("oom.openChat")
    static let startCall  = Notification.Name("oom.startCall")
    static let openListing = Notification.Name("oom.openListing")
    static let reportUser  = Notification.Name("oom.reportUser")
}

/// Carried as `Notification.object` on `AppEvents.startCall`. Plain Strings + Bool so any
/// file can post this without importing StreamVideo.
struct StartCallRequest {
    let calleeId: String
    let calleeName: String
    let audioOnly: Bool
    let listingTitle: String?
}

struct OpenChatRequest {
    let channelId: String   // bare ID, e.g. "listing-airpods"
    let listingTitle: String?
}

struct ReportUserRequest {
    let userId: String
    let reason: String
    let context: String  // "chat" / "video" / "feed"
}
