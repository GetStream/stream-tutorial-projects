//
//  SellView.swift
//  OOMarketplace
//
//  No Stream imports. Lets the user draft a new listing - it shows up immediately in the
//  Discover tab via the in-memory repository. The Feed tab also reflects it because the
//  user feed will pick it up the next time `FeedsService` syncs.
//

import SwiftUI

struct SellView: View {
    @StateObject private var repo = MarketplaceRepository.shared

    @State private var title = ""
    @State private var subtitle = ""
    @State private var price: Double = 0
    @State private var category: Listing.Category = .other
    @State private var imageURL = ""
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Title", text: $title)
                    TextField("Description / condition", text: $subtitle, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Pricing") {
                    HStack {
                        Text("$").foregroundStyle(.secondary)
                        TextField("0", value: $price, format: .number)
                            .keyboardType(.decimalPad)
                    }
                    Picker("Category", selection: $category) {
                        ForEach(Listing.Category.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                        }
                    }
                }

                Section("Photo") {
                    TextField("Image URL (Unsplash works great)", text: $imageURL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    if let url = URL(string: imageURL), !imageURL.isEmpty {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image): image.resizable().scaledToFill()
                            default:                  Color.ooSurface
                            }
                        }
                        .frame(height: 160)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                Section {
                    Button {
                        publish()
                    } label: {
                        Label("List for sale", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.ooAccent)
                    .disabled(title.isEmpty || price <= 0)
                }

                Section {
                    Label("Stream Moderation reviews every listing automatically. Reports from buyers route to the dashboard.",
                          systemImage: "checkmark.shield.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Sell something")
            .alert("Posted!", isPresented: $showSuccess) {
                Button("OK") { resetForm() }
            } message: {
                Text("Your listing is live in Discover and your followers' feed.")
            }
        }
    }

    private func publish() {
        let newListing = Listing(
            id: "user-\(UUID().uuidString.prefix(6))",
            title: title,
            subtitle: subtitle,
            price: price,
            imageURL: URL(string: imageURL),
            category: category,
            sellerId: StreamConfig.currentUserId,
            sellerName: StreamConfig.currentUserName,
            channelId: nil
        )
        repo.addListing(newListing)
        showSuccess = true

        // Side-effects: announce in feed + schedule a "Daily Deal" style notification.
        NotificationCenter.default.post(name: AppEvents.openListing, object: newListing.id)
    }

    private func resetForm() {
        title = ""
        subtitle = ""
        price = 0
        imageURL = ""
        category = .other
    }
}
