import SwiftUI
import SafariServices

struct POIDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let poi: POI

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                    // Hero image placeholder
                    if let imageURL = poi.imageURL {
                        AsyncImage(url: imageURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(AppTheme.secondaryBackground)
                                .overlay(Image(systemName: poi.category.systemImage).font(.largeTitle).foregroundStyle(.tertiary))
                        }
                        .frame(height: 200)
                        .clipped()
                    }

                    VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(poi.category.displayName)
                                    .font(.caption.bold())
                                    .foregroundStyle(poi.isHighlighted ? .orange : .secondary)

                                if poi.isHighlighted {
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.yellow)
                                }
                            }

                            Text(poi.name)
                                .font(.title2.bold())

                            if let desc = poi.detailedDescription {
                                Text(desc)
                                    .font(AppTheme.bodyFont)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Rating & status
                        HStack(spacing: AppTheme.spacingMedium) {
                            if let rating = poi.rating {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                                    Text(String(format: "%.1f", rating)).bold()
                                    if let count = poi.reviewCount {
                                        Text("(\(count))").foregroundStyle(.secondary)
                                    }
                                }
                            }

                            if let isOpen = poi.isOpenNow {
                                Text(isOpen ? "Open now" : "Closed")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(isOpen ? .green : .red)
                            }
                        }
                        .font(.subheadline)

                        Divider()

                        // Details
                        if let hours = poi.openingHours {
                            DetailRow(icon: "clock", title: "Hours", value: hours)
                        }

                        if let fee = poi.admissionFee {
                            DetailRow(icon: "ticket", title: "Admission", value: fee)
                        }

                        if let phone = poi.phoneNumber {
                            DetailRow(icon: "phone", title: "Phone", value: phone)
                        }

                        if let accessibility = poi.accessibilityInfo {
                            DetailRow(icon: "figure.roll", title: "Accessibility", value: accessibility)
                        }

                        // Action buttons
                        VStack(spacing: AppTheme.spacingSmall) {
                            if let bookingURL = poi.bookingURL {
                                LinkButton(title: "Book Tickets", icon: "ticket.fill", url: bookingURL, color: .orange)
                            }

                            if let websiteURL = poi.websiteURL {
                                LinkButton(title: "Visit Website", icon: "safari", url: websiteURL, color: AppTheme.primary)
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.spacingMedium)
                }
                .padding(.bottom, AppTheme.spacingLarge)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
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
                .font(AppTheme.headlineFont)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(color)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
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
