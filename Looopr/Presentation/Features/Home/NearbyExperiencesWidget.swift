import SwiftUI

struct NearbyExperiencesWidget: View {
    let experiences: [NearbyExperience]
    @State private var selectedExperience: NearbyExperience?

    var body: some View {
        VStack(alignment: .leading, spacing: LoooprTheme.Spacing.sm) {
            HStack {
                Text(L10n.NearbyExperiences.title)
                    .font(LoooprTheme.Typography.label)
                    .foregroundStyle(LoooprTheme.Colors.textTertiary)

                Spacer()

                Text(L10n.NearbyExperiences.poweredByGetYourGuide)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(LoooprTheme.Colors.textTertiary)
            }
            .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LoooprTheme.Spacing.cardGap) {
                    ForEach(experiences) { experience in
                        ExperienceCard(experience: experience) {
                            selectedExperience = experience
                        }
                    }
                }
                .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
            }
        }
        .sheet(item: $selectedExperience) { experience in
            SafariView(url: experience.bookingURL)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Experience Card

private struct ExperienceCard: View {
    let experience: NearbyExperience
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Image placeholder / async image
                AsyncImage(url: experience.imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        LoooprTheme.Colors.primaryLight
                            .overlay {
                                Image(systemName: "binoculars.fill")
                                    .font(.system(size: LoooprTheme.Typography.xl))
                                    .foregroundStyle(LoooprTheme.Colors.primary.opacity(0.4))
                            }
                    }
                }
                .frame(height: 100)
                .clipped()

                VStack(alignment: .leading, spacing: LoooprTheme.Spacing.xxs) {
                    Text(experience.title)
                        .font(LoooprTheme.Typography.subheadline)
                        .foregroundStyle(LoooprTheme.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: LoooprTheme.Spacing.xxs) {
                        if let rating = experience.rating {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(LoooprTheme.Colors.warning)
                                Text(String(format: "%.1f", rating))
                                    .font(LoooprTheme.Typography.caption)
                                    .foregroundStyle(LoooprTheme.Colors.textSecondary)
                            }
                        }

                        if let count = experience.reviewCount {
                            Text("(\(count))")
                                .font(LoooprTheme.Typography.caption)
                                .foregroundStyle(LoooprTheme.Colors.textTertiary)
                        }
                    }

                    if let price = experience.price {
                        Text(price)
                            .font(LoooprTheme.Typography.caption)
                            .foregroundStyle(LoooprTheme.Colors.primary)
                    }
                }
                .padding(.horizontal, LoooprTheme.Spacing.xs)
                .padding(.vertical, LoooprTheme.Spacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 180, height: 200)
            .background(LoooprTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.card))
            .loooprShadow(LoooprTheme.Shadows.md)
        }
        .buttonStyle(.plain)
    }
}

