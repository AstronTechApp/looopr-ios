import Foundation

enum UnitPreference: String, CaseIterable {
    case system  // follows device locale
    case metric  // km, m
    case imperial  // mi, ft

    var label: String {
        switch self {
        case .system: return String(localized: "settings.unitPreference.system", defaultValue: "System Default", bundle: LocalizationManager.shared.localizedBundle)
        case .metric: return String(localized: "settings.unitPreference.metric", defaultValue: "Metric (km, m)", bundle: LocalizationManager.shared.localizedBundle)
        case .imperial: return String(localized: "settings.unitPreference.imperial", defaultValue: "Imperial (mi, ft)", bundle: LocalizationManager.shared.localizedBundle)
        }
    }

    /// Resolves .system to metric or imperial based on device locale
    var resolved: ResolvedUnitSystem {
        switch self {
        case .system:
            return Locale.current.measurementSystem == .us ? .imperial : .metric
        case .metric:
            return .metric
        case .imperial:
            return .imperial
        }
    }
}

enum ResolvedUnitSystem {
    case metric
    case imperial

    var distanceUnit: String {
        switch self {
        case .metric: return "km"
        case .imperial: return "mi"
        }
    }

    var shortDistanceUnit: String {
        switch self {
        case .metric: return "m"
        case .imperial: return "ft"
        }
    }

    var elevationUnit: String {
        switch self {
        case .metric: return "m"
        case .imperial: return "ft"
        }
    }

    var speedUnit: String {
        switch self {
        case .metric: return String(localized: "units.speed.kmh", defaultValue: "km/h", bundle: LocalizationManager.shared.localizedBundle)
        case .imperial: return String(localized: "units.speed.mph", defaultValue: "mph", bundle: LocalizationManager.shared.localizedBundle)
        }
    }

    var paceUnit: String {
        switch self {
        case .metric: return String(localized: "units.pace.minKm", defaultValue: "min/km", bundle: LocalizationManager.shared.localizedBundle)
        case .imperial: return String(localized: "units.pace.minMi", defaultValue: "min/mi", bundle: LocalizationManager.shared.localizedBundle)
        }
    }
}

// MARK: - UnitFormatter

struct UnitFormatter {
    let unitSystem: ResolvedUnitSystem

    // MARK: - Initialization

    init(unitPreference: UnitPreference = .system) {
        self.unitSystem = unitPreference.resolved
    }

    init(unitSystem: ResolvedUnitSystem) {
        self.unitSystem = unitSystem
    }

    // MARK: - Static Methods

    static func format(distanceMeters: Double, unitSystem: ResolvedUnitSystem) -> String {
        switch unitSystem {
        case .metric:
            if distanceMeters >= 1000 {
                let km = distanceMeters / 1000
                return String(format: "%.1f km", km)
            } else {
                return String(format: "%.0f m", distanceMeters)
            }
        case .imperial:
            let miles = distanceMeters * 0.000621371
            if miles >= 0.1 {
                return String(format: "%.1f mi", miles)
            } else {
                let feet = distanceMeters * 3.28084
                return String(format: "%.0f ft", feet)
            }
        }
    }

    static func format(distanceKm: Double, unitSystem: ResolvedUnitSystem) -> String {
        return format(distanceMeters: distanceKm * 1000, unitSystem: unitSystem)
    }

    static func format(elevationMeters: Double, unitSystem: ResolvedUnitSystem) -> String {
        switch unitSystem {
        case .metric:
            return String(format: "+%.0f m", elevationMeters)
        case .imperial:
            let feet = elevationMeters * 3.28084
            return String(format: "+%.0f ft", feet)
        }
    }

    static func format(speedKmh: Double, unitSystem: ResolvedUnitSystem) -> String {
        switch unitSystem {
        case .metric:
            return String(format: "~%.1f km/h", speedKmh)
        case .imperial:
            let mph = speedKmh * 0.621371
            return String(format: "~%.1f mph", mph)
        }
    }

    static func format(paceMinPerKm: Double, unitSystem: ResolvedUnitSystem) -> String {
        let minutes = Int(paceMinPerKm)
        let seconds = Int((paceMinPerKm - Double(minutes)) * 60)

        switch unitSystem {
        case .metric:
            return String(format: "%d:%02d min/km", minutes, seconds)
        case .imperial:
            let paceMinPerMi = paceMinPerKm * 1.60934
            let miMinutes = Int(paceMinPerMi)
            let miSeconds = Int((paceMinPerMi - Double(miMinutes)) * 60)
            return String(format: "%d:%02d min/mi", miMinutes, miSeconds)
        }
    }

    // MARK: - Instance Methods

    func formatDistance(meters: Double) -> String {
        UnitFormatter.format(distanceMeters: meters, unitSystem: unitSystem)
    }

    func formatDistance(km: Double) -> String {
        UnitFormatter.format(distanceKm: km, unitSystem: unitSystem)
    }

    func formatElevation(meters: Double) -> String {
        UnitFormatter.format(elevationMeters: meters, unitSystem: unitSystem)
    }

    func formatSpeed(kmh: Double) -> String {
        UnitFormatter.format(speedKmh: kmh, unitSystem: unitSystem)
    }

    func formatPace(minPerKm: Double) -> String {
        UnitFormatter.format(paceMinPerKm: minPerKm, unitSystem: unitSystem)
    }

    // MARK: - Unit Labels

    var distanceUnit: String {
        unitSystem.distanceUnit
    }

    var shortDistanceUnit: String {
        unitSystem.shortDistanceUnit
    }

    var elevationUnit: String {
        unitSystem.elevationUnit
    }

    var speedUnit: String {
        unitSystem.speedUnit
    }

    var paceUnit: String {
        unitSystem.paceUnit
    }
}

// MARK: - SettingsManager.Units bridge

extension SettingsManager.Units {
    /// Convert to the resolved unit system for UnitFormatter
    var resolvedUnitSystem: ResolvedUnitSystem {
        switch self {
        case .kilometres: return .metric
        case .miles: return .imperial
        }
    }
}
