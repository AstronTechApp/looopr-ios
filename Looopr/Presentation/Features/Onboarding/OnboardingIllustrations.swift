import SwiftUI

// Static, non-interactive replicas of real Looopr UI, used as the visual on
// each onboarding page. They mirror HomeView / RouteDetailView /
// WalkNavigationView styling so the intro looks like the app itself.

// MARK: - Page 1 · Duration card

struct OnboardingDurationIllustration: View {
    var body: some View {
        VStack(spacing: LoooprTheme.Spacing.lg) {
            HStack(alignment: .bottom) {
                Text(L10n.Home.howLongWalk)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(LoooprTheme.Colors.textSecondary)
                    .frame(maxWidth: 130, alignment: .leading)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("45")
                        .font(.system(size: 68, weight: .heavy, design: .rounded))
                        .tracking(-2)
                        .foregroundStyle(LoooprTheme.Colors.primary)
                    Text(L10n.Onboarding.minutesUnit)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(1.5)
                        .foregroundStyle(LoooprTheme.Colors.primary.opacity(0.6))
                }
            }

            VStack(spacing: LoooprTheme.Spacing.xxs) {
                // Slider (static)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LoooprTheme.Colors.surfaceContainerHigh)
                        .frame(height: 28)
                    Capsule()
                        .fill(LoooprTheme.Colors.primary)
                        .frame(width: 70, height: 8)
                        .padding(.leading, 12)
                    Circle()
                        .fill(LoooprTheme.Colors.surface)
                        .frame(width: 26, height: 26)
                        .overlay(Circle().strokeBorder(LoooprTheme.Colors.primary, lineWidth: 3))
                        .overlay(Circle().fill(LoooprTheme.Colors.primary).frame(width: 8, height: 8))
                        .padding(.leading, 68)
                }
                .frame(height: 44)

                HStack {
                    Text(L10n.Home.duration15min)
                    Spacer()
                    Text(L10n.Home.duration3h)
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(LoooprTheme.Colors.textTertiary)
                .padding(.horizontal, 4)
            }

            VStack(spacing: 10) {
                Text(L10n.Home.walkingPace)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(LoooprTheme.Colors.textTertiary)

                HStack(spacing: 10) {
                    ForEach(SettingsManager.WalkingPace.allCases, id: \.self) { pace in
                        let isActive = pace == .moderate
                        VStack(spacing: 6) {
                            Image(systemName: icon(for: pace))
                                .font(.system(size: 24, weight: isActive ? .semibold : .regular))
                                .symbolVariant(isActive ? .fill : .none)
                            Text(pace.label)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .textCase(.uppercase)
                                .tracking(0.8)
                            Text(pace.kilometresPerHour.formattedSpeed(units: SettingsManager.shared.preferredUnits))
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .opacity(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isActive ? AnyShapeStyle(LoooprTheme.Colors.primary) : AnyShapeStyle(LoooprTheme.Colors.surfaceContainer))
                        .foregroundStyle(isActive ? LoooprTheme.Colors.textOnPrimary : LoooprTheme.Colors.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.card))
                        .overlay(
                            isActive
                                ? RoundedRectangle(cornerRadius: LoooprTheme.Radius.card).strokeBorder(LoooprTheme.Colors.primaryLight, lineWidth: 3)
                                : nil
                        )
                        .shadow(color: isActive ? LoooprTheme.Colors.primary.opacity(0.25) : .clear, radius: isActive ? 8 : 0, y: isActive ? 4 : 0)
                    }
                }
            }
        }
        .padding(LoooprTheme.Spacing.xl)
        .background(LoooprTheme.Colors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.xl))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func icon(for pace: SettingsManager.WalkingPace) -> String {
        switch pace {
        case .leisure:  return "figure.mind.and.body"
        case .moderate: return "figure.walk"
        case .brisk:    return "bolt"
        }
    }
}

// MARK: - Page 2 · Route card with points of interest

struct OnboardingRouteIllustration: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingMiniMap(showPOIs: true)
                .frame(height: 140)

            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.Onboarding.sampleRouteName)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(LoooprTheme.Colors.textPrimary)

                HStack(spacing: 8) {
                    statPill("figure.walk", "4.0 km")
                    statPill("clock", "49 min")
                    statPill("arrow.up.right", "+72 m")
                }

                Text(L10n.Onboarding.pointsOfInterest)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(LoooprTheme.Colors.textTertiary)
                    .padding(.top, 2)

                poiRow(icon: "building.columns.fill", name: "Westerkerk", detail: L10n.Onboarding.onRoute("0.6 km"), rating: "4.7")
                poiRow(icon: "tree.fill", name: "Vondelpark", detail: L10n.Onboarding.onRoute("1.9 km"), rating: "4.6")
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
        .background(LoooprTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.xxl))
        .loooprShadow(LoooprTheme.Shadows.card)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func statPill(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .bold))
            Text(text).font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(LoooprTheme.Colors.primaryDark)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(LoooprTheme.Colors.primaryLight)
        .clipShape(Capsule())
    }

    private func poiRow(icon: String, name: String, detail: String, rating: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(LoooprTheme.Colors.textSecondary)
                .frame(width: 40, height: 40)
                .background(LoooprTheme.Colors.surfaceContainer)
                .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.md))

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(LoooprTheme.Colors.textPrimary)
                Text(detail)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(LoooprTheme.Colors.textSecondary)
            }

            Spacer()

            HStack(spacing: 3) {
                Image(systemName: "star.fill").font(.system(size: 11))
                Text(rating).font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(LoooprTheme.Colors.textPrimary)
        }
    }
}

// MARK: - Page 3 · Turn-by-turn navigation

struct OnboardingNavigationIllustration: View {
    var body: some View {
        ZStack(alignment: .top) {
            OnboardingMiniMap(showPOIs: false, loopOffsetY: 26, loopScale: 0.8)

            VStack(spacing: 10) {
                // Turn banner
                HStack(spacing: 14) {
                    Image(systemName: "arrow.turn.up.left")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("20 m")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Westermarkt")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(L10n.Onboarding.sampleNextTurn)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                }
                .padding(16)
                .background(Color(hex: "#2C2C2B"))
                .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.xl))
            }
            .padding(16)

            // Stats bar
            VStack {
                Spacer()
                HStack(spacing: 0) {
                    stat(L10n.Onboarding.statTime, "1:06")
                    stat(L10n.Onboarding.statDistance, "49 m")
                    stat(L10n.Onboarding.statRemaining, "4.0 km")
                    Circle()
                        .fill(LoooprTheme.Colors.error)
                        .frame(width: 36, height: 36)
                }
                .padding(.leading, 20)
                .padding(.trailing, 16)
                .padding(.vertical, 14)
                .background(LoooprTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .padding(16)
            }
        }
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.xxl))
        .loooprShadow(LoooprTheme.Shadows.card)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundStyle(LoooprTheme.Colors.textTertiary)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(LoooprTheme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Shared stylised map

/// A lightweight drawn map (roads, canal, park, red loop) so the intro never
/// needs MapKit, network or location before the user has signed in.
struct OnboardingMiniMap: View {
    var showPOIs: Bool
    var loopOffsetY: CGFloat = 0
    var loopScale: CGFloat = 1

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cx = w / 2
            let cy = h / 2 + loopOffsetY
            let rx = min(w, h) * 0.36 * loopScale
            let ry = rx * 0.62

            ZStack {
                Color(hex: "#EFEBE1")

                // Roads
                ForEach([0.22, 0.52, 0.82], id: \.self) { f in
                    Rectangle().fill(Color.white).frame(height: 5).position(x: cx, y: h * f)
                }
                ForEach([0.2, 0.5, 0.78], id: \.self) { f in
                    Rectangle().fill(Color.white).frame(width: 5).position(x: w * f, y: h / 2)
                }

                // Park
                Ellipse()
                    .fill(Color(hex: "#CFE3C2"))
                    .frame(width: w * 0.28, height: h * 0.36)
                    .position(x: w * 0.82, y: h * 0.22)

                // Canal
                Rectangle()
                    .fill(Color(hex: "#BFD9EE"))
                    .frame(width: w * 1.3, height: 24)
                    .rotationEffect(.degrees(-6))
                    .position(x: cx, y: h * 0.78)

                // Loop
                LoopShape(center: CGPoint(x: cx, y: cy), rx: rx, ry: ry)
                    .stroke(Color(hex: "#E5393B"), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

                // Start
                Circle()
                    .fill(LoooprTheme.Colors.primary)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                    .position(x: cx - rx, y: cy + ry * 0.45)

                if showPOIs {
                    pin(Color(hex: "#D9822B")).position(x: cx + rx * 0.1, y: cy - ry * 0.9)
                    pin(Color(hex: "#C2185B")).position(x: cx + rx * 1.1, y: cy + ry * 0.1)
                    pin(LoooprTheme.Colors.primary).position(x: cx - rx * 0.45, y: cy + ry * 1.05)
                } else {
                    // User position marker on the loop
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(LoooprTheme.Colors.primary)
                        .shadow(color: .white, radius: 2)
                        .rotationEffect(.degrees(35))
                        .position(x: cx - rx * 0.9, y: cy - ry * 0.3)
                }
            }
        }
    }

    private func pin(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 18, height: 18)
            .overlay(Circle().strokeBorder(.white, lineWidth: 3))
    }
}

private struct LoopShape: Shape {
    let center: CGPoint
    let rx: CGFloat
    let ry: CGFloat

    func path(in rect: CGRect) -> Path {
        let cx = center.x, cy = center.y
        var p = Path()
        p.move(to: CGPoint(x: cx - rx, y: cy + ry * 0.45))
        p.addCurve(to: CGPoint(x: cx + rx * 0.1, y: cy - ry * 0.9),
                   control1: CGPoint(x: cx - rx * 1.3, y: cy - ry * 0.3),
                   control2: CGPoint(x: cx - rx * 0.65, y: cy - ry))
        p.addCurve(to: CGPoint(x: cx + rx * 1.05, y: cy + ry * 0.5),
                   control1: CGPoint(x: cx + rx, y: cy - ry * 0.8),
                   control2: CGPoint(x: cx + rx * 1.3, y: cy - ry * 0.1))
        p.addCurve(to: CGPoint(x: cx - rx, y: cy + ry * 0.45),
                   control1: CGPoint(x: cx + rx * 0.75, y: cy + ry * 1.05),
                   control2: CGPoint(x: cx - rx * 0.45, y: cy + ry * 1.1))
        p.closeSubpath()
        return p
    }
}
