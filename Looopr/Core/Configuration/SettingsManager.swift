import Foundation
import UIKit
import UserNotifications

@MainActor @Observable
final class SettingsManager {
    static let shared = SettingsManager()
    private init() {
        // Load initial values from UserDefaults
        _displayName = UserDefaults.standard.string(forKey: Keys.displayName) ?? "Walker"
        _preferredUnits = Units(rawValue: UserDefaults.standard.string(forKey: Keys.preferredUnits) ?? Units.kilometres.rawValue) ?? .kilometres
        _unitPreference = UnitPreference(rawValue: UserDefaults.standard.string(forKey: Keys.unitPreference) ?? UnitPreference.system.rawValue) ?? .system
        _walkingPace = WalkingPace(rawValue: UserDefaults.standard.string(forKey: Keys.walkingPace) ?? WalkingPace.moderate.rawValue) ?? .moderate

        _walkReminderEnabled = UserDefaults.standard.bool(forKey: Keys.walkReminderEnabled)

        let interval = UserDefaults.standard.double(forKey: Keys.walkReminderTime)
        if interval == 0 {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            components.hour = 9
            components.minute = 0
            _walkReminderTime = Calendar.current.date(from: components) ?? Date()
        } else {
            _walkReminderTime = Date(timeIntervalSince1970: interval)
        }

        _weeklyProgressEnabled = UserDefaults.standard.bool(forKey: Keys.weeklyProgressEnabled)
    }

    // MARK: - Keys

    private enum Keys {
        static let displayName = "settings.displayName"
        static let preferredUnits = "settings.preferredUnits"
        static let unitPreference = "settings.unitPreference"
        static let walkingPace = "settings.walkingPace"
        static let walkReminderEnabled = "settings.walkReminderEnabled"
        static let walkReminderTime = "settings.walkReminderTime"
        static let weeklyProgressEnabled = "settings.weeklyProgressEnabled"
    }

    // MARK: - Units

    enum Units: String, CaseIterable {
        case kilometres = "km"
        case miles = "mi"

        var label: String {
            switch self {
            case .kilometres: return String(localized: "settings.units.kilometres", defaultValue: "Kilometres (km)", bundle: LocalizationManager.shared.localizedBundle)
            case .miles: return String(localized: "settings.units.miles", defaultValue: "Miles (mi)", bundle: LocalizationManager.shared.localizedBundle)
            }
        }
    }

    // MARK: - Walking Pace

    enum WalkingPace: String, CaseIterable {
        case leisure, moderate, brisk

        var label: String {
            switch self {
            case .leisure: return L10n.WalkingPace.leisure
            case .moderate: return L10n.WalkingPace.moderate
            case .brisk: return L10n.WalkingPace.brisk
            }
        }

        /// Pace description with unit-aware speed label.
        func subtitle(units: Units) -> String {
            let speed = kilometresPerHour.formattedSpeed(units: units)
            switch self {
            case .leisure: return "\(speed), \(L10n.WalkingPace.leisureDescription)"
            case .moderate: return "\(speed), \(L10n.WalkingPace.moderateDescription)"
            case .brisk: return "\(speed), \(L10n.WalkingPace.briskDescription)"
            }
        }

        /// Average metres per minute for each pace — used for duration estimates
        var metresPerMinute: Double {
            switch self {
            case .leisure: return 67    // ~4 km/h
            case .moderate: return 83   // ~5 km/h
            case .brisk: return 100     // ~6 km/h
            }
        }

        var kilometresPerHour: Double {
            (metresPerMinute * 60) / 1000
        }
    }

    // MARK: - Observable Properties

    var displayName: String {
        didSet { UserDefaults.standard.set(displayName, forKey: Keys.displayName) }
    }

    var unitPreference: UnitPreference {
        didSet {
            UserDefaults.standard.set(unitPreference.rawValue, forKey: Keys.unitPreference)
            // Sync the legacy preferredUnits to maintain backward compatibility
            switch unitPreference.resolved {
            case .metric: preferredUnits = .kilometres
            case .imperial: preferredUnits = .miles
            }
            NotificationCenter.default.post(name: .unitsDidChange, object: nil)
        }
    }

    var preferredUnits: Units {
        didSet {
            UserDefaults.standard.set(preferredUnits.rawValue, forKey: Keys.preferredUnits)
            NotificationCenter.default.post(name: .unitsDidChange, object: nil)
        }
    }

    var walkingPace: WalkingPace {
        didSet {
            UserDefaults.standard.set(walkingPace.rawValue, forKey: Keys.walkingPace)
            NotificationCenter.default.post(name: .walkingPaceDidChange, object: nil)
        }
    }

    var walkReminderEnabled: Bool {
        didSet {
            UserDefaults.standard.set(walkReminderEnabled, forKey: Keys.walkReminderEnabled)
            if walkReminderEnabled {
                scheduleWalkReminder()
            } else {
                cancelWalkReminder()
            }
        }
    }

    var walkReminderTime: Date {
        didSet {
            UserDefaults.standard.set(walkReminderTime.timeIntervalSince1970, forKey: Keys.walkReminderTime)
            if walkReminderEnabled {
                scheduleWalkReminder()
            }
        }
    }

    var weeklyProgressEnabled: Bool {
        didSet {
            UserDefaults.standard.set(weeklyProgressEnabled, forKey: Keys.weeklyProgressEnabled)
            if weeklyProgressEnabled {
                scheduleWeeklyProgressNotification()
            } else {
                cancelWeeklyProgressNotification()
            }
        }
    }

    // MARK: - Notification Scheduling

    func scheduleWalkReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["looopr.walkReminder"]
        )
        guard walkReminderEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = L10n.Notifications.timeForLooopr
        content.body = L10n.Notifications.getOutside
        content.sound = .default

        let triggerComponents = Calendar.current.dateComponents(
            [.hour, .minute], from: walkReminderTime
        )
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: triggerComponents, repeats: true
        )
        let request = UNNotificationRequest(
            identifier: "looopr.walkReminder",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelWalkReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["looopr.walkReminder"]
        )
    }

    func scheduleWeeklyProgressNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["looopr.weeklyProgress"]
        )
        guard weeklyProgressEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = L10n.Notifications.weeklySummary
        content.body = L10n.Notifications.checkOutProgress
        content.sound = .default

        var components = DateComponents()
        components.weekday = 1  // Sunday
        components.hour = 18
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components, repeats: true
        )
        let request = UNNotificationRequest(
            identifier: "looopr.weeklyProgress",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelWeeklyProgressNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["looopr.weeklyProgress"]
        )
    }

    /// Request notification authorisation. Returns true if granted.
    func requestNotificationAuthorisation() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound]
            )
        } catch {
            return false
        }
    }

    // MARK: - App Launch Restore

    func restoreOnLaunch() {
        if walkReminderEnabled {
            scheduleWalkReminder()
        }
        if weeklyProgressEnabled {
            scheduleWeeklyProgressNotification()
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let unitsDidChange = Notification.Name("UnitsDidChange")
    static let walkingPaceDidChange = Notification.Name("WalkingPaceDidChange")
    static let languageDidChange = Notification.Name("LanguageDidChange")
}
