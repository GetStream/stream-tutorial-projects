//
//  DiscoverView.swift
//  OOMarketplace
//
//  No Stream imports. Uses NotificationCenter (AppEvents) to bridge to Chat / Video / Feeds.
//

import SwiftUI

/// Product image that prefers a bundled asset (named after the listing id) and falls
/// back to a remote URL. Bundling guarantees the demo always shows the real photo even
/// when `AsyncImage`'s network fetch is slow or fails on the simulator (which was
/// turning the Linen Sofa / Boxset listings into placeholder icons).
struct ProductImage<Placeholder: View>: View {
    let assetName: String?
    let url: URL?
    private let placeholder: Placeholder

    init(assetName: String?, url: URL?, @ViewBuilder placeholder: () -> Placeholder) {
        self.assetName = assetName
        self.url = url
        self.placeholder = placeholder()
    }

    var body: some View {
        if let assetName, UIImage(named: assetName) != nil {
            Image(assetName).resizable().scaledToFill()
        } else {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    placeholder
                }
            }
        }
    }
}

struct DiscoverView: View {
    @StateObject private var repo = MarketplaceRepository.shared
    @State private var query = ""
    @State private var selectedCategory: Listing.Category?
    @State private var sheetListing: Listing?

    private var filteredListings: [Listing] {
        repo.listings.filter { listing in
            (selectedCategory == nil || listing.category == selectedCategory!)
            && (query.isEmpty
                || listing.title.localizedCaseInsensitiveContains(query)
                || listing.subtitle.localizedCaseInsensitiveContains(query)
                || listing.sellerName.localizedCaseInsensitiveContains(query))
        }
    }

    private var dailyDeals: [Listing] { repo.dailyDeals() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !dailyDeals.isEmpty {
                        dailyDealsSection
                    }
                    categoryStrip
                    listingsGrid
                    favoritesSection
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("Discover")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search items, sellers, or descriptions")
            .sheet(item: $sheetListing) { listing in
                ListingDetailView(listing: listing)
            }
        }
    }

    // MARK: - Sections

    private var dailyDealsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Daily deals", systemImage: "bolt.fill")
                    .font(.title3.bold())
                Spacer()
                Text("Limited time")
                    .font(.caption.bold())
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.ooAccent.opacity(0.15), in: Capsule())
                    .foregroundStyle(Color.ooAccent)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(dailyDeals) { listing in
                        DailyDealCard(listing: listing) { sheetListing = listing }
                            .frame(width: 260)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                CategoryChip(label: "All", icon: "square.grid.2x2",
                             isSelected: selectedCategory == nil) { selectedCategory = nil }
                ForEach(Listing.Category.allCases, id: \.self) { category in
                    CategoryChip(label: category.rawValue, icon: category.icon,
                                 isSelected: selectedCategory == category) {
                        selectedCategory = selectedCategory == category ? nil : category
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var listingsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
            ForEach(filteredListings) { listing in
                ListingCard(listing: listing) { sheetListing = listing }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var favoritesSection: some View {
        if !repo.favorites.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Your faves", systemImage: "heart.fill")
                    .font(.title3.bold())
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(repo.listings.filter { repo.isFavorite($0.id) }) { listing in
                            ListingCard(listing: listing, isCompact: true) {
                                sheetListing = listing
                            }
                            .frame(width: 180)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - Category chip

private struct CategoryChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(
                    isSelected ? Color.ooAccent : Color(.tertiarySystemFill),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Listing cards

struct ListingCard: View {
    let listing: Listing
    var isCompact: Bool = false
    let onTap: () -> Void

    @StateObject private var repo = MarketplaceRepository.shared

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    ProductImage(assetName: listing.id, url: listing.imageURL) {
                        ZStack {
                            Color.ooSurface
                            Image(systemName: listing.category.icon)
                                .font(.title)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: isCompact ? 120 : 150)
                    .clipped()

                    Button {
                        repo.toggleFavorite(listing.id)
                    } label: {
                        Image(systemName: repo.isFavorite(listing.id) ? "heart.fill" : "heart")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(repo.isFavorite(listing.id) ? Color.ooAccent : .white)
                            .padding(8)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(listing.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(.primary)
                    Text("$\(Int(listing.price))")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(Color.ooAccent)
                    Text("by \(listing.sellerName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct DailyDealCard: View {
    let listing: Listing
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ProductImage(assetName: listing.id, url: listing.imageURL) {
                    Color.ooSurface
                }
                .frame(width: 80, height: 80)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(listing.title)
                        .font(.subheadline.bold())
                        .lineLimit(2)
                    HStack {
                        Text("$\(Int(listing.price * 0.75))")
                            .font(.callout.bold())
                            .foregroundStyle(Color.ooAccent)
                        Text("$\(Int(listing.price))")
                            .font(.caption)
                            .strikethrough()
                            .foregroundStyle(.secondary)
                    }
                    if let end = listing.dealEndsAt {
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                            Text(end, style: .relative)
                        }
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(
                LinearGradient(colors: [Color.ooAccent.opacity(0.15), Color.ooAccent.opacity(0.03)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.ooAccent.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
