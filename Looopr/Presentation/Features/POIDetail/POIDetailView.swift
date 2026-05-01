import SwiftUI
import SafariServices

struct POIDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let poi: POI
    var departureDate: Date?
    @State private var enrichedPOI: POI?
    @State private var isEnriching = false
    @State private var ticketResult: TicketResult?
    @State private var isLoadingTickets = false
    @State private var showAllOffers = false

    /// The POI to display — enriched version if available, otherwise the original.
    private var displayPOI: POI {
        enrichedPOI ?? poi
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LoooprTheme.Spacing.md) {
                    // Loading indicator while enriching
                    if isEnriching {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.8)
                            Text(L10n.POIDetail.loadingDetails)
                                .font(.subheadline)
                                .foregroundStyle(LoooprTheme.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, LoooprTheme.Spacing.md)
                    }

                    // Hero image placeholder
                    if let imageURL = displayPOI.imageURL {
                        AsyncImage(url: imageURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(LoooprTheme.Colors.surfaceSecondary)
                                .overlay(
                                    Image(systemName: displayPOI.category.systemImage)
                                        .font(.largeTitle)
                                        .foregroundStyle(LoooprTheme.Colors.textTertiary)
                                )
                        }
                        .frame(height: 200)
                        .clipped()
                    }

                    VStack(alignment: .leading, spacing: LoooprTheme.Spacing.md) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(displayPOI.category.displayName)
                                    .font(.caption.bold())
                                    .foregroundStyle(displayPOI.isHighlighted ? .orange : LoooprTheme.Colors.textSecondary)

                                if displayPOI.isHighlighted {
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .foregroundStyle(LoooprTheme.Colors.warning)
                                }
                            }

                            Text(displayPOI.name)
                                .font(.title2.bold())
                                .foregroundStyle(LoooprTheme.Colors.textPrimary)

                            Text(displayPOI.displayDescription)
                                .font(LoooprTheme.Typography.body)
                                .foregroundStyle(LoooprTheme.Colors.textSecondary)
                        }

                        // Rating & status
                        HStack(spacing: LoooprTheme.Spacing.md) {
                            if let rating = displayPOI.rating {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(LoooprTheme.Colors.warning)
                                    Text(String(format: "%.1f", rating))
                                        .bold()
                                        .foregroundStyle(LoooprTheme.Colors.textPrimary)
                                    if let count = displayPOI.reviewCount {
                                        Text("(\(count))")
                                            .foregroundStyle(LoooprTheme.Colors.textSecondary)
                                    }
                                }
                            }

                            let openStatus = displayPOI.openStatus(at: departureDate)
                            if openStatus != .unknown {
                                Text(openStatusLabel(for: openStatus))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(openStatus == .open || openStatus == .openingSoon ? .green : .red)
                            }
                        }
                        .font(.subheadline)

                        Divider()

                        // Details
                        if let hours = displayPOI.openingHours {
                            DetailRow(icon: "clock", title: "Hours", value: hours)
                        }

                        if let fee = displayPOI.admissionFee {
                            DetailRow(icon: "ticket", title: "Admission", value: fee)
                        }

                        if let phone = displayPOI.phoneNumber {
                            DetailRow(icon: "phone", title: "Phone", value: phone)
                        }

                        if let accessibility = displayPOI.accessibilityInfo {
                            DetailRow(icon: "figure.roll", title: "Accessibility", value: accessibility)
                        }

                        // "View on Google Maps" button (for food POIs from Google Places New)
                        if let mapsURL = displayPOI.googleMapsUri {
                            LinkButton(title: L10n.POIDetail.viewOnGoogleMaps, icon: "map.fill", url: mapsURL, color: LoooprTheme.Colors.primary)
                        }

                        // Action buttons (CTA strategy based on booking strategy)
                        VStack(spacing: LoooprTheme.Spacing.xs) {
                            switch displayPOI.bookingCTAStrategy {
                            case .getYourGuide:
                                bookingCTAGetYourGuide()

                            case .website:
                                bookingCTAWebsite()

                            case .none:
                                bookingCTANone()
                            }
                        }
                    }
                    .padding(.horizontal, LoooprTheme.Spacing.md)
                }
                .padding(.bottom, LoooprTheme.Spacing.lg)
            }
            .background(LoooprTheme.Colors.surface)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Misc.done) { dismiss() }
                        .foregroundStyle(LoooprTheme.Colors.primary)
                }
            }
            .task {
                // On-demand enrichment: fetch Google Place Details for food
                // POIs that haven't been enriched yet. Attraction POIs skip
                // enrichment entirely (MapKit data is sufficient) to eliminate
                // Google Places API costs (~$0.025 per POI).
                if !poi.isEnriched && poi.category.isFood {
                    isEnriching = true
                    let enrichmentService = ServiceContainer.shared.resolve(POIEnriching.self)
                    if let enriched = await enrichmentService.enrich(poi: poi, minRating: nil) {
                        enrichedPOI = enriched
                    }
                    isEnriching = false
                }

                // Load tickets only for GetYourGuide strategy without a direct booking URL
                let p = displayPOI
                guard p.bookingCTAStrategy == .getYourGuide,
                      p.bookingURL == nil else { return }

                isLoadingTickets = true
                if let aggregator = ServiceContainer.shared.resolveOptional(TicketAggregating.self) {
                    ticketResult = await aggregator.findBestTicket(for: p)
                }
                isLoadingTickets = false
            }
        }
    }

    // MARK: - Booking CTA Builders

    private func openStatusLabel(for status: OpenStatus) -> String {
        switch status {
        case .open:
            return departureDate == nil ? L10n.POI.openNow : L10n.POI.openThen
        case .openingSoon:
            return L10n.POI.openingSoon
        case .closed:
            return departureDate == nil ? L10n.POI.closed : L10n.POI.closedThen
        case .unknown:
            return ""
        }
    }

    /// GetYourGuide strategy: primary booking CTA with provider comparison.
    @ViewBuilder
    private func bookingCTAGetYourGuide() -> some View {
        let p = displayPOI
        // Ticket section
        if isLoadingTickets {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text(L10n.POIDetail.findingTickets)
                    .font(.subheadline)
                    .foregroundStyle(LoooprTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(LoooprTheme.Colors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.sm))
        } else if let bookingURL = p.bookingURL {
            LinkButton(title: L10n.POIDetail.bookTickets, icon: "ticket.fill", url: bookingURL, color: .orange)
        } else if let best = ticketResult?.bestOffer {
            LinkButton(title: L10n.POIDetail.bookOn(best.providerName), icon: "ticket.fill", url: best.bookingURL, color: .orange)

            if let offers = ticketResult?.offers, offers.count > 1 {
                Button { showAllOffers.toggle() } label: {
                    HStack {
                        Text(L10n.POIDetail.compareProviders(offers.count))
                            .font(.caption)
                        Image(systemName: showAllOffers ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(.orange)
                }

                if showAllOffers {
                    ForEach(offers.dropFirst(1)) { offer in
                        LinkButton(
                            title: "\(offer.providerName) — \(offer.price ?? "See price")",
                            icon: "ticket",
                            url: offer.bookingURL,
                            color: LoooprTheme.Colors.textSecondary
                        )
                    }
                }
            }
        } else if let fallback = ticketResult?.fallbackURL {
            LinkButton(title: L10n.POIDetail.buyTickets, icon: "ticket.fill", url: fallback, color: .orange)
        }

        // Secondary buttons
        if let websiteURL = p.websiteURL {
            LinkButton(title: L10n.POIDetail.visitWebsite, icon: "safari", url: websiteURL, color: LoooprTheme.Colors.primary)
        }

        if let phone = p.phoneNumber, let phoneURL = URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))") {
            LinkButton(title: L10n.POIDetail.call, icon: "phone.fill", url: phoneURL, color: .green)
        }
    }

    /// Website strategy: primary CTA is "Visit Website" (for cinemas, theaters, stadiums).
    @ViewBuilder
    private func bookingCTAWebsite() -> some View {
        let p = displayPOI
        // Primary: "Visit Website" (only if available)
        if let websiteURL = p.websiteURL {
            LinkButton(title: L10n.POIDetail.visitWebsite, icon: "safari", url: websiteURL, color: LoooprTheme.Colors.primary)
        }

        // Secondary: "Call" (if available)
        if let phone = p.phoneNumber, let phoneURL = URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))") {
            LinkButton(title: L10n.POIDetail.call, icon: "phone.fill", url: phoneURL, color: .green)
        }
    }

    /// No strategy: show website and call only, no booking CTA.
    @ViewBuilder
    private func bookingCTANone() -> some View {
        let p = displayPOI
        // Show website if available
        if let websiteURL = p.websiteURL {
            LinkButton(title: L10n.POIDetail.visitWebsite, icon: "safari", url: websiteURL, color: LoooprTheme.Colors.primary)
        }

        // Show call if available
        if let phone = p.phoneNumber, let phoneURL = URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))") {
            LinkButton(title: L10n.POIDetail.call, icon: "phone.fill", url: phoneURL, color: .green)
        }
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: LoooprTheme.Spacing.xs) {
            Image(systemName: icon)
                .foregroundStyle(LoooprTheme.Colors.textSecondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(LoooprTheme.Colors.textSecondary)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(LoooprTheme.Colors.textPrimary)
            }
        }
    }
}

// MARK: - Link Button

private struct LinkButton: View {
    let title: String
    let icon: String
    let url: URL
    let color: Color
    @State private var showSafari = false

    var body: some View {
        Button { showSafari = true } label: {
            Label(title, systemImage: icon)
                .font(LoooprTheme.Typography.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(color)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.sm))
        }
        .sheet(isPresented: $showSafari) {
            SafariView(url: url)
        }
    }
}

// MARK: - Safari View

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
