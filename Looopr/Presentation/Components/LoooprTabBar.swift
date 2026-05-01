import SwiftUI

// MARK: - Tab Definition

enum LoooprTab: String, CaseIterable {
    case home
    case explore
    case savedRoutes
    case profile

    var title: String {
        switch self {
        case .home: return L10n.Tab.home
        case .explore: return L10n.Tab.explore
        case .savedRoutes: return L10n.Tab.savedRoutes
        case .profile: return L10n.Tab.profile
        }
    }

    /// Outlined SF Symbol (inactive state)
    var icon: String {
        switch self {
        case .home:        return "house"
        case .explore:     return "location"
        case .savedRoutes: return "bookmark"
        case .profile:     return "person"
        }
    }

    /// Filled SF Symbol (active state)
    var activeIcon: String {
        switch self {
        case .home:        return "house.fill"
        case .explore:     return "location.fill"
        case .savedRoutes: return "bookmark.fill"
        case .profile:     return "person.fill"
        }
    }
}

// MARK: - Tab Bar View (Liquid Glass)

struct LoooprTabBar: View {
    @Binding var selectedTab: LoooprTab
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            ForEach(LoooprTab.allCases, id: \.self) { tab in
                LoooprTabItem(
                    tab: tab,
                    isSelected: selectedTab == tab
                ) {
                    withAnimation(LoooprTheme.Animation.snappy) {
                        selectedTab = tab
                    }
                }
            }
        }
        .frame(height: 56)
        .padding(.horizontal, LoooprTheme.Spacing.sm)
        .background(
            ZStack {
                // Layer 1: Ultra-thin blur — lets content show through
                RoundedRectangle(cornerRadius: LoooprTheme.Radius.full, style: .continuous)
                    .fill(.ultraThinMaterial)

                // Layer 2: Adaptive tint so icons stay readable
                RoundedRectangle(cornerRadius: LoooprTheme.Radius.full, style: .continuous)
                    .fill(
                        colorScheme == .dark
                            ? Color.black.opacity(0.35)
                            : Color.white.opacity(0.35)
                    )

                // Layer 3: Specular highlight — top-edge light refraction
                RoundedRectangle(cornerRadius: LoooprTheme.Radius.full, style: .continuous)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(colorScheme == .dark ? 0.18 : 0.45), location: 0.0),
                                .init(color: .white.opacity(colorScheme == .dark ? 0.04 : 0.08), location: 0.35),
                                .init(color: .clear, location: 0.6)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Layer 4: Glass border — 0.5pt stroke for edge definition
                RoundedRectangle(cornerRadius: LoooprTheme.Radius.full, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(colorScheme == .dark ? 0.25 : 0.6),
                                .white.opacity(colorScheme == .dark ? 0.08 : 0.2)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            }
            .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
        )
        .padding(.horizontal, LoooprTheme.Spacing.md)
    }
}

// MARK: - Tab Item

private struct LoooprTabItem: View {
    let tab: LoooprTab
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var scale: CGFloat = 1.0

    /// Inactive label color that stays readable on the glass surface
    private var inactiveColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.55)
            : Color(hex: "#595c59")
    }

    var body: some View {
        Button {
            // Spring scale: 0.9 → 1.05 → 1.0
            withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                scale = 0.9
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                    scale = 1.05
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    scale = 1.0
                }
            }
            onTap()
        } label: {
            if isSelected {
                // Active state — gradient pill
                VStack(spacing: 3) {
                    Image(systemName: tab.activeIcon)
                        .font(.system(size: 18, weight: .semibold))

                    Text(tab.title)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#1B5E20"), Color(hex: "#66BB6A")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: LoooprTheme.Colors.primary.opacity(0.3), radius: 8, y: 4)
            } else {
                // Inactive state
                VStack(spacing: 3) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 18))

                    Text(tab.title)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
                .foregroundColor(inactiveColor)
                .padding(.vertical, 10)
            }
        }
        .frame(maxWidth: .infinity)
        .scaleEffect(scale)
        .buttonStyle(.plain)
    }
}
