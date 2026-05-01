import Foundation

extension Double {
    /// Formats a distance in metres using the given unit system.
    /// Use this overload in non-MainActor contexts.
    func formattedDistance(units: SettingsManager.Units) -> String {
        switch units {
        case .kilometres:
            if self < 1000 {
                return "\(Int(self)) m"
            } else {
                return String(format: "%.1f km", self / 1000)
            }
        case .miles:
            let miles = self / 1609.34
            if miles < 0.1 {
                return "\(Int(self * 3.28084)) ft"
            } else {
                return String(format: "%.1f mi", miles)
            }
        }
    }

    /// Formats kilometres using the given unit system.
    /// Use this overload in non-MainActor contexts.
    func formattedDistanceFromKm(units: SettingsManager.Units) -> String {
        (self * 1000).formattedDistance(units: units)
    }

    /// Formats an elevation value in metres using the given unit system.
    /// Always displays as a whole number with a "+" prefix.
    func formattedElevation(units: SettingsManager.Units) -> String {
        switch units {
        case .kilometres:
            return "+\(Int(self)) m"
        case .miles:
            let feet = self * 3.28084
            return "+\(Int(feet)) ft"
        }
    }

    /// Formats a speed in km/h using the given unit system.
    func formattedSpeed(units: SettingsManager.Units) -> String {
        switch units {
        case .kilometres:
            return String(format: "~%.0f km/h", self)
        case .miles:
            let mph = self * 0.621371
            return String(format: "~%.0f mph", mph)
        }
    }
}

@MainActor
extension Double {
    /// Formats a distance in metres using the user's preferred unit system.
    func formattedDistance() -> String {
        formattedDistance(units: SettingsManager.shared.preferredUnits)
    }

    /// Formats kilometres using the user's preferred unit system.
    func formattedDistanceFromKm() -> String {
        (self * 1000).formattedDistance()
    }

    /// Formats an elevation value in metres using the user's preferred unit system.
    func formattedElevation() -> String {
        formattedElevation(units: SettingsManager.shared.preferredUnits)
    }

    /// Formats a speed in km/h using the user's preferred unit system.
    func formattedSpeed() -> String {
        formattedSpeed(units: SettingsManager.shared.preferredUnits)
    }

    /// Returns the short unit label for the user's preferred unit system.
    static var distanceUnit: String {
        switch SettingsManager.shared.preferredUnits {
        case .kilometres: return "km"
        case .miles: return "mi"
        }
    }

    /// Returns the short elevation unit label for the user's preferred unit system.
    static var elevationUnit: String {
        switch SettingsManager.shared.preferredUnits {
        case .kilometres: return "m"
        case .miles: return "ft"
        }
    }

    /// Converts kilometres to the user's preferred unit.
    var inPreferredUnit: Double {
        switch SettingsManager.shared.preferredUnits {
        case .kilometres: return self
        case .miles: return self / 1.60934
        }
    }
}

extension Int {
    /// Formats an integer distance in metres using the user's preferred unit system.
    @MainActor
    func formattedDistance() -> String {
        Double(self).formattedDistance()
    }

    /// Formats an integer elevation in metres using the user's preferred unit system.
    @MainActor
    func formattedElevation() -> String {
        Double(self).formattedElevation()
    }
}
