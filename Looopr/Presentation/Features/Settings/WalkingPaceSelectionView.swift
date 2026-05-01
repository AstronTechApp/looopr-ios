import SwiftUI

struct WalkingPaceSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = SettingsManager.shared

    var body: some View {
        ZStack {
            LoooprTheme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Navigation bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: LoooprTheme.Typography.lg, weight: .semibold))
                            .foregroundStyle(LoooprTheme.Colors.textPrimary)
                    }

                    Spacer()

                    Text(L10n.Settings.walkingPace)
                        .font(LoooprTheme.Typography.headline)
                        .foregroundStyle(LoooprTheme.Colors.textPrimary)

                    Spacer()

                    // Invisible spacer for centering
                    Color.clear.frame(width: 24, height: 24)
                }
                .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
                .padding(.top, LoooprTheme.Spacing.sm)
                .padding(.bottom, LoooprTheme.Spacing.lg)

                VStack(spacing: 0) {
                    ForEach(SettingsManager.WalkingPace.allCases, id: \.self) { pace in
                        Button {
                            settings.walkingPace = pace
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pace.label)
                                        .font(LoooprTheme.Typography.body)
                                        .foregroundStyle(LoooprTheme.Colors.textPrimary)
                                    Text(pace.subtitle(units: SettingsManager.shared.preferredUnits))
                                        .font(LoooprTheme.Typography.caption)
                                        .foregroundStyle(LoooprTheme.Colors.textSecondary)
                                }

                                Spacer()

                                if settings.walkingPace == pace {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: LoooprTheme.Typography.md, weight: .bold))
                                        .foregroundStyle(LoooprTheme.Colors.primary)
                                }
                            }
                            .padding(.horizontal, LoooprTheme.Spacing.md)
                            .padding(.vertical, LoooprTheme.Spacing.md)
                        }
                        .buttonStyle(.plain)

                        if pace != SettingsManager.WalkingPace.allCases.last {
                            Divider()
                                .padding(.leading, LoooprTheme.Spacing.md)
                        }
                    }
                }
                .background(LoooprTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.card))
                .loooprShadow(LoooprTheme.Shadows.sm)
                .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)

                Spacer()
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }
}
