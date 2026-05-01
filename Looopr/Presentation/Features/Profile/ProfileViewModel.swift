import Foundation
import Charts

// MARK: - Weekly Distance Data Point

struct WeeklyDistance: Identifiable {
    let id = UUID()
    let weekStart: Date
    let kilometres: Double
}

// MARK: - View Model

@MainActor @Observable
final class ProfileViewModel {

    // MARK: - State

    private(set) var completedWalks: [WalkSession] = []
    private(set) var weeklyDistances: [WeeklyDistance] = []

    // This-week aggregates
    private(set) var weekDistance: Double = 0       // km
    private(set) var weekSteps: Int = 0
    private(set) var weekDurationSeconds: TimeInterval = 0
    private(set) var weekElevation: Double = 0      // metres

    // Streak & totals
    private(set) var streakWeeks: Int = 0
    private(set) var totalWalkCount: Int = 0

    // Tab
    var selectedTab: ProfileTab = .progress

    // Dependencies
    private let walkHistoryRepository: WalkHistoryRepository

    init(
        walkHistoryRepository: WalkHistoryRepository = ServiceContainer.shared.resolve(WalkHistoryRepository.self)
    ) {
        self.walkHistoryRepository = walkHistoryRepository
    }

    // MARK: - Load

    func loadData() {
        guard let sessions = try? walkHistoryRepository.loadAll() else { return }

        // Only completed walks, sorted most recent first
        completedWalks = sessions
            .filter { $0.isComplete }
            .sorted { ($0.finishedAt ?? $0.startedAt) > ($1.finishedAt ?? $1.startedAt) }

        totalWalkCount = completedWalks.count

        computeThisWeekStats()
        computeWeeklyDistances()
        computeStreak()

    }

    // MARK: - This Week Stats

    private func computeThisWeekStats() {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return }

        let thisWeekWalks = completedWalks.filter { ($0.finishedAt ?? $0.startedAt) >= weekStart }

        weekDistance = thisWeekWalks.reduce(0) { $0 + $1.distanceKilometers }
        weekSteps = thisWeekWalks.reduce(0) { $0 + $1.stepCount }
        weekDurationSeconds = thisWeekWalks.reduce(0) { $0 + $1.durationSeconds }
        weekElevation = thisWeekWalks.reduce(0) { $0 + ($1.elevationGainMeters ?? 0) }
    }

    // MARK: - Weekly Distances (Past 8 Weeks)

    private func computeWeeklyDistances() {
        let calendar = Calendar.current
        let now = Date()

        var distances: [WeeklyDistance] = []

        for weeksAgo in (0..<8).reversed() {
            guard let targetDate = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: now),
                  let weekInterval = calendar.dateInterval(of: .weekOfYear, for: targetDate) else {
                continue
            }

            let km = completedWalks
                .filter { session in
                    let date = session.finishedAt ?? session.startedAt
                    return date >= weekInterval.start && date < weekInterval.end
                }
                .reduce(0.0) { $0 + $1.distanceKilometers }

            distances.append(WeeklyDistance(weekStart: weekInterval.start, kilometres: km))
        }

        weeklyDistances = distances
    }

    // MARK: - Streak

    private func computeStreak() {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = Date()

        while true {
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: checkDate) else { break }

            let hasWalk = completedWalks.contains { session in
                let date = session.finishedAt ?? session.startedAt
                return date >= weekInterval.start && date < weekInterval.end
            }

            if hasWalk {
                streak += 1
                guard let previousWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: checkDate) else { break }
                checkDate = previousWeek
            } else {
                break
            }
        }

        streakWeeks = streak
    }

    // MARK: - Formatters

    var weekDistanceFormatted: String {
        String(format: "%.1f", weekDistance.inPreferredUnit)
    }

    var weekStepsFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: weekSteps)) ?? "\(weekSteps)"
    }

    var weekDurationFormatted: String {
        let hours = Int(weekDurationSeconds) / 3600
        let minutes = (Int(weekDurationSeconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)min"
        }
        return "\(minutes)min"
    }

    var weekElevationFormatted: String {
        switch SettingsManager.shared.preferredUnits {
        case .kilometres:
            return "+\(Int(weekElevation))"
        case .miles:
            return "+\(Int(weekElevation * 3.28084))"
        }
    }

}

// MARK: - Profile Tab

enum ProfileTab: String, CaseIterable {
    case progress = "Progress"
    case activities = "Activities"

    var title: String {
        switch self {
        case .progress: return L10n.Profile.tabProgress
        case .activities: return L10n.Profile.tabActivities
        }
    }
}
