import CoreLocation
import SwiftUI

@MainActor @Observable
final class HomeViewModel {

    // MARK: - Published state

    var walkDuration: Double = 30
    var recentRoutes: [Route] = []
    var savedRoutes: [Route] = []
    var nearbyExperiences: [NearbyExperience] = []
    var isLoadingExperiences = false

    /// Custom location selected via location search, nil means use GPS
    var selectedLocation: SelectedLocation?
    var isUsingCurrentLocation: Bool = true

    /// Display name for the location field
    var locationDisplayName: String {
        isUsingCurrentLocation ? L10n.Home.currentLocation : (selectedLocation?.displayName ?? L10n.Home.currentLocation)
    }

    func selectLocation(_ location: SelectedLocation) {
        selectedLocation = location
        isUsingCurrentLocation = false
    }

    func selectCurrentLocation() {
        selectedLocation = nil
        isUsingCurrentLocation = true
    }

    private let routeRepository: RouteRepository
    private let experiencesService: NearbyExperiencesService
    private let locationService: LocationProviding

    init(
        routeRepository: RouteRepository? = nil,
        experiencesService: NearbyExperiencesService? = nil,
        locationService: LocationProviding? = nil
    ) {
        self.routeRepository = routeRepository ?? ServiceContainer.shared.resolve(RouteRepository.self)
        self.experiencesService = experiencesService ?? NearbyExperiencesService()
        self.locationService = locationService ?? ServiceContainer.shared.resolve(LocationProviding.self)
        loadSavedRoutes()
    }

    func loadSavedRoutes() {
        do {
            savedRoutes = try routeRepository.loadSavedRoutes()
        } catch {
            // If decoding fails (e.g. schema change), log and reset to empty
            savedRoutes = []
            #if DEBUG
            print("[HomeViewModel] Failed to load saved routes: \(error)")
            #endif
        }
    }

    func loadNearbyExperiences() {
        guard nearbyExperiences.isEmpty, !isLoadingExperiences else { return }
        guard let coordinate = locationService.currentCoordinate else { return }
        isLoadingExperiences = true

        Task {
            let experiences = await experiencesService.fetchExperiences(near: coordinate)
            nearbyExperiences = experiences
            isLoadingExperiences = false
        }
    }

    // MARK: - Derived

    var durationLabel: String {
        let minutes = Int(walkDuration)
        if minutes >= 60 {
            let hrs = minutes / 60
            let rem = minutes % 60
            if rem == 0 {
                return "\(hrs)h"
            }
            return "\(hrs)h \(rem)min"
        }
        return "\(minutes)min"
    }

    /// The numeric part only — for the editorial large display.
    var durationNumberOnly: String {
        let minutes = Int(walkDuration)
        if minutes >= 60 {
            let hrs = minutes / 60
            let rem = minutes % 60
            if rem == 0 { return "\(hrs)" }
            return "\(hrs):\(String(format: "%02d", rem))"
        }
        return "\(minutes)"
    }

    /// The unit label only — "min", "h", "h min".
    var durationUnitOnly: String {
        let minutes = Int(walkDuration)
        if minutes >= 60 {
            let rem = minutes % 60
            if rem == 0 { return L10n.Time.h }
            return L10n.Time.hMin
        }
        return L10n.Time.min
    }

    /// Time-of-day greeting
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return L10n.Home.goodMorning
        case 12..<17: return L10n.Home.goodAfternoon
        case 17..<21: return L10n.Home.goodEvening
        default:      return L10n.Home.goodEvening
        }
    }

    // MARK: - Slider

    /// Snap to nearest 5-minute increment
    func snapDuration() {
        walkDuration = (walkDuration / 5).rounded() * 5
    }
}
