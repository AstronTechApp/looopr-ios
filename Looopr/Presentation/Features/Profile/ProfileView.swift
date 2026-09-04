import SwiftUI
import Charts
import MapKit

struct ProfileView: View {
    @State private var viewModel = ProfileViewModel()
    @State private var settings = SettingsManager.shared
    @State private var showSettings = false

    var body: some View {
        ZStack {
            LoooprTheme.Colors.background
                .ignoresSafeArea()

        VStack(spacing: 0) {
            // Navigation bar
            HStack {
                Text(L10n.Profile.title)
                    .font(LoooprTheme.Typography.largeTitle)
                    .foregroundStyle(LoooprTheme.Colors.textPrimary)

                Spacer()

                NavigationLink(value: AppRoute.settings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: LoooprTheme.Typography.lg))
                        .foregroundStyle(LoooprTheme.Colors.textSecondary)
                }
            }
            .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
            .padding(.top, LoooprTheme.Spacing.sm)
            .padding(.bottom, LoooprTheme.Spacing.md)

            // Profile header
            profileHeader

            // Tab switcher
            tabSwitcher
                .padding(.top, LoooprTheme.Spacing.md)

            // Content
            ScrollView {
                VStack(spacing: 0) {
                    switch viewModel.selectedTab {
                    case .progress:
                        progressContent
                    case .activities:
                        activitiesContent
                    }
                }
                .padding(.bottom, LoooprTheme.Spacing.huge + LoooprTheme.Spacing.xxl)
            }
        }
        .onAppear {
            viewModel.loadData()
        }
        } // ZStack
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .alert(L10n.Profile.deleteWalkQuestion,
               isPresented: Binding(
                   get: { viewModel.walkPendingDeletion != nil },
                   set: { if !$0 { viewModel.walkPendingDeletion = nil } }
               ),
               presenting: viewModel.walkPendingDeletion) { _ in
            Button(L10n.Profile.deleteWalk, role: .destructive) {
                viewModel.confirmPendingDeletion()
            }
            Button(L10n.Profile.cancel, role: .cancel) {
                viewModel.walkPendingDeletion = nil
            }
        } message: { session in
            Text(L10n.Profile.willBeDeleted(session.routeName ?? L10n.Misc.walk))
        }
        .alert(L10n.Profile.deleteFailedTitle, isPresented: $viewModel.deleteFailedWarning) {
            Button(L10n.Misc.okay, role: .cancel) {}
        } message: {
            Text(L10n.Profile.deleteFailedMessage)
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        HStack(spacing: LoooprTheme.Spacing.md) {
            // Avatar circle with initials
            Circle()
                .fill(LoooprTheme.Colors.primaryLight)
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(LoooprTheme.Colors.primary)
                )

            VStack(alignment: .leading, spacing: LoooprTheme.Spacing.xxs) {
                Text(settings.displayName)
                    .font(LoooprTheme.Typography.title)
                    .foregroundStyle(LoooprTheme.Colors.textPrimary)

                Text(L10n.Profile.walksCompleted(viewModel.totalWalkCount))
                    .font(LoooprTheme.Typography.subheadline)
                    .foregroundStyle(LoooprTheme.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
    }

    // MARK: - Tab Switcher

    private var tabSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(ProfileTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(LoooprTheme.Animation.snappy) {
                        viewModel.selectedTab = tab
                    }
                } label: {
                    Text(tab.title)
                        .font(LoooprTheme.Typography.headline)
                        .foregroundStyle(
                            viewModel.selectedTab == tab
                                ? LoooprTheme.Colors.textOnPrimary
                                : LoooprTheme.Colors.textPrimary
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, LoooprTheme.Spacing.sm)
                        .background(
                            viewModel.selectedTab == tab
                                ? LoooprTheme.Colors.primary
                                : LoooprTheme.Colors.surface
                        )
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.chip))
        .overlay(
            RoundedRectangle(cornerRadius: LoooprTheme.Radius.chip)
                .strokeBorder(LoooprTheme.Colors.border, lineWidth: 1)
        )
        .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
    }

    // MARK: - Progress Content

    private var progressContent: some View {
        VStack(spacing: LoooprTheme.Spacing.md) {
            thisWeekCard
            weeklyChartCard
            streakCard

            if viewModel.totalWalkCount == 0 {
                emptyProgressHint
            }
        }
        .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
        .padding(.vertical, LoooprTheme.Spacing.md)
    }

    // MARK: - This Week Card

    private var thisWeekCard: some View {
        VStack(alignment: .leading, spacing: LoooprTheme.Spacing.md) {
            Text(L10n.Profile.thisWeek)
                .font(LoooprTheme.Typography.label)
                .foregroundStyle(LoooprTheme.Colors.textTertiary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: LoooprTheme.Spacing.md) {
                StatCell(
                    icon: "figure.walk",
                    value: viewModel.weekDistanceFormatted,
                    unit: Double.distanceUnit,
                    label: L10n.Profile.distance
                )
                StatCell(
                    icon: "shoe.2",
                    value: viewModel.weekStepsFormatted,
                    unit: nil,
                    label: L10n.Profile.steps
                )
                StatCell(
                    icon: "clock",
                    value: viewModel.weekDurationFormatted,
                    unit: nil,
                    label: L10n.Profile.time
                )
                StatCell(
                    icon: "arrow.up.right",
                    value: viewModel.weekElevationFormatted,
                    unit: Double.elevationUnit,
                    label: L10n.Profile.elevationGain
                )
            }
        }
        .padding(LoooprTheme.Spacing.md)
        .background(LoooprTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.card))
        .loooprShadow(LoooprTheme.Shadows.sm)
    }

    // MARK: - Weekly Chart Card

    private var weeklyChartCard: some View {
        VStack(alignment: .leading, spacing: LoooprTheme.Spacing.sm) {
            Text(L10n.Profile.past8Weeks)
                .font(LoooprTheme.Typography.label)
                .foregroundStyle(LoooprTheme.Colors.textTertiary)

            Chart(viewModel.weeklyDistances) { week in
                LineMark(
                    x: .value("Week", week.weekStart, unit: .weekOfYear),
                    y: .value("km", week.kilometres)
                )
                .foregroundStyle(LoooprTheme.Colors.primary)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Week", week.weekStart, unit: .weekOfYear),
                    y: .value("km", week.kilometres)
                )
                .foregroundStyle(LoooprTheme.Colors.primary)
                .symbolSize(30)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .font(LoooprTheme.Typography.caption)
                        .foregroundStyle(LoooprTheme.Colors.textTertiary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(LoooprTheme.Colors.border)
                    AxisValueLabel()
                        .font(LoooprTheme.Typography.caption)
                        .foregroundStyle(LoooprTheme.Colors.textTertiary)
                }
            }
            .chartYAxisLabel("km", position: .trailing)
            .frame(height: 180)
        }
        .padding(LoooprTheme.Spacing.md)
        .background(LoooprTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.card))
        .loooprShadow(LoooprTheme.Shadows.sm)
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        HStack {
            VStack(spacing: LoooprTheme.Spacing.xxs) {
                Image(systemName: "flame.fill")
                    .font(.system(size: LoooprTheme.Typography.xl))
                    .foregroundStyle(LoooprTheme.Colors.primary)

                Text("\(viewModel.streakWeeks)")
                    .font(LoooprTheme.Typography.title)
                    .foregroundStyle(LoooprTheme.Colors.textPrimary)

                Text(L10n.Profile.weekStreak)
                    .font(LoooprTheme.Typography.caption)
                    .foregroundStyle(LoooprTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(LoooprTheme.Colors.border)
                .frame(width: 1, height: 60)

            VStack(spacing: LoooprTheme.Spacing.xxs) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: LoooprTheme.Typography.xl))
                    .foregroundStyle(LoooprTheme.Colors.primary)

                Text("\(viewModel.totalWalkCount)")
                    .font(LoooprTheme.Typography.title)
                    .foregroundStyle(LoooprTheme.Colors.textPrimary)

                Text(L10n.Profile.totalWalks)
                    .font(LoooprTheme.Typography.caption)
                    .foregroundStyle(LoooprTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(LoooprTheme.Spacing.md)
        .background(LoooprTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.card))
        .loooprShadow(LoooprTheme.Shadows.sm)
    }

    // MARK: - Empty Progress Hint

    private var emptyProgressHint: some View {
        HStack(spacing: LoooprTheme.Spacing.sm) {
            Image(systemName: "figure.walk")
                .font(.system(size: LoooprTheme.Typography.lg))
                .foregroundStyle(LoooprTheme.Colors.primary)

            Text(L10n.Profile.completeFirstLooopr)
                .font(LoooprTheme.Typography.subheadline)
                .foregroundStyle(LoooprTheme.Colors.textSecondary)
        }
        .padding(LoooprTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LoooprTheme.Colors.primaryLight)
        .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.card))
    }

    // MARK: - Activities Content

    private var activitiesContent: some View {
        VStack(spacing: LoooprTheme.Spacing.md) {
            if viewModel.completedWalks.isEmpty {
                emptyActivitiesState
                    .padding(.top, LoooprTheme.Spacing.huge)
            } else {
                ForEach(viewModel.completedWalks) { session in
                    ActivityCard(
                        session: session,
                        viewModel: viewModel,
                        onDelete: { viewModel.requestDelete(session) }
                    )
                }
            }
        }
        .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
        .padding(.vertical, LoooprTheme.Spacing.md)
    }

    // MARK: - Empty Activities State

    private var emptyActivitiesState: some View {
        VStack(spacing: LoooprTheme.Spacing.sm) {
            Image(systemName: "figure.walk")
                .font(.system(size: 48))
                .foregroundStyle(LoooprTheme.Colors.primary)

            Text(L10n.Profile.noWalksYet)
                .font(LoooprTheme.Typography.title)
                .foregroundStyle(LoooprTheme.Colors.textPrimary)

            Text(L10n.Profile.startLoooprDescription)
                .font(LoooprTheme.Typography.subheadline)
                .foregroundStyle(LoooprTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Stat Cell

private struct StatCell: View {
    let icon: String
    let value: String
    let unit: String?
    let label: String

    var body: some View {
        VStack(spacing: LoooprTheme.Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: LoooprTheme.Typography.lg))
                .foregroundStyle(LoooprTheme.Colors.primary)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(LoooprTheme.Typography.title)
                    .foregroundStyle(LoooprTheme.Colors.textPrimary)

                if let unit {
                    Text(unit)
                        .font(LoooprTheme.Typography.caption)
                        .foregroundStyle(LoooprTheme.Colors.textSecondary)
                }
            }

            Text(label)
                .font(LoooprTheme.Typography.caption)
                .foregroundStyle(LoooprTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LoooprTheme.Spacing.sm)
    }
}

// MARK: - Activity Card

private struct ActivityCard: View {
    let session: WalkSession
    let viewModel: ProfileViewModel
    let onDelete: () -> Void

    @State private var isShowingShare = false

    private var walkDate: String {
        let date = session.finishedAt ?? session.startedAt
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }

    private var statsLine: String {
        var parts: [String] = []

        parts.append(session.distanceWalkedMeters.formattedDistance())

        let totalSeconds = Int(session.durationSeconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            parts.append(String(format: "%dh %02dmin", hours, minutes))
        } else {
            parts.append("\(minutes)min")
        }

        if session.stepCount > 0 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            let steps = formatter.string(from: NSNumber(value: session.stepCount)) ?? "\(session.stepCount)"
            parts.append("\(steps) steps")
        }

        return parts.joined(separator: " · ")
    }

    private var activityColor: Color {
        if let colorIndex = session.routeColorIndex {
            return AppTheme.routeColor(for: colorIndex)
        }
        return LoooprTheme.Colors.primary
    }

    private var healthBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .font(.system(size: 9, weight: .semibold))

            Text(L10n.Profile.inAppleHealth)
                .font(LoooprTheme.Typography.caption)
        }
        .foregroundStyle(LoooprTheme.Colors.primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(LoooprTheme.Colors.primaryLight.opacity(0.35))
        .clipShape(Capsule())
        .padding(.top, 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tappable area — map, name and date open the walk detail.
            // The action row below sits *outside* this link, otherwise the
            // NavigationLink swallows the share and delete taps.
            NavigationLink(value: AppRoute.walkDetail(session)) {
                VStack(alignment: .leading, spacing: 0) {
                    // Route map preview or placeholder
                    Group {
                        let coordinates = session.displayCoordinates
                        if !coordinates.isEmpty {
                            ActivityMapPreview(
                                coordinates: coordinates,
                                color: activityColor
                            )
                        } else {
                            ZStack {
                                LoooprTheme.Colors.primaryLight
                                Image(systemName: "map")
                                    .font(.system(size: 32))
                                    .foregroundStyle(LoooprTheme.Colors.primary.opacity(0.5))
                            }
                        }
                    }
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: LoooprTheme.Radius.card,
                            topTrailingRadius: LoooprTheme.Radius.card
                        )
                    )

                    VStack(alignment: .leading, spacing: LoooprTheme.Spacing.xs) {
                        Text(session.routeName ?? L10n.Misc.walk)
                            .font(LoooprTheme.Typography.headline)
                            .foregroundStyle(LoooprTheme.Colors.textPrimary)
                            .multilineTextAlignment(.leading)

                        Text(walkDate)
                            .font(LoooprTheme.Typography.subheadline)
                            .foregroundStyle(LoooprTheme.Colors.textSecondary)

                        // Only set once the workout actually landed in HealthKit.
                        if session.healthKitWorkoutID != nil {
                            healthBadge
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, LoooprTheme.Spacing.md)
                    .padding(.top, LoooprTheme.Spacing.md)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Stats + actions
            HStack {
                Text(statsLine)
                    .font(LoooprTheme.Typography.caption)
                    .foregroundStyle(LoooprTheme.Colors.textTertiary)

                Spacer()

                Button {
                    isShowingShare = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: LoooprTheme.Typography.md))
                        .foregroundStyle(LoooprTheme.Colors.primary)
                        .frame(width: 44, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: LoooprTheme.Typography.md))
                        .foregroundStyle(LoooprTheme.Colors.error)
                        .frame(width: 44, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Profile.deleteWalk)
            }
            .padding(.horizontal, LoooprTheme.Spacing.md)
            .padding(.top, LoooprTheme.Spacing.xs)
            .padding(.bottom, LoooprTheme.Spacing.md)
        }
        .background(LoooprTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.card))
        .loooprShadow(LoooprTheme.Shadows.sm)
        .sheet(isPresented: $isShowingShare) {
            let name = session.routeName ?? L10n.Misc.walk
            let text = L10n.Share.walkedRoute(name)
            ActivitySheet(items: [text])
        }
    }
}

// MARK: - Activity Map Preview

private struct ActivityMapPreview: View {
    let coordinates: [CLLocationCoordinate2D]
    let color: Color

    var body: some View {
        Map {
            MapPolyline(coordinates: coordinates)
                .stroke(color, lineWidth: 3)

            if let start = coordinates.first {
                Annotation("", coordinate: start) {
                    Circle()
                        .fill(LoooprTheme.Colors.primary)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(.white, lineWidth: 1.5))
                }
            }

            if let end = coordinates.last, coordinates.count > 1 {
                Annotation("", coordinate: end) {
                    Circle()
                        .fill(LoooprTheme.Colors.routeDot)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(.white, lineWidth: 1.5))
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .allowsHitTesting(false)
    }
}

// MARK: - Share Sheet

private struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
