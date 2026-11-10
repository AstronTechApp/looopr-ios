import Foundation

/// A JSON-encodable property value for analytics events.
/// Keeps the domain layer free of any Supabase types while still producing
/// proper jsonb (numbers stay numbers, so they are directly queryable in SQL).
enum AnalyticsValue: Codable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case stringArray([String])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v):      try container.encode(v)
        case .int(let v):         try container.encode(v)
        case .double(let v):      try container.encode(v)
        case .bool(let v):        try container.encode(v)
        case .stringArray(let v): try container.encode(v)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self)     { self = .bool(v);        return }
        if let v = try? container.decode(Int.self)      { self = .int(v);         return }
        if let v = try? container.decode(Double.self)   { self = .double(v);      return }
        if let v = try? container.decode(String.self)   { self = .string(v);      return }
        if let v = try? container.decode([String].self) { self = .stringArray(v); return }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unsupported AnalyticsValue"
        )
    }
}

enum AnalyticsEvent: Sendable {
    case appOpened
    /// `latitude`/`longitude` are the search start rounded to 2 decimals
    /// (~1 km, Apple's "coarse location"): enough to see which areas fail,
    /// not where someone lives. Nil while GPS has no fix yet.
    case routeSearchStarted(minutes: Int, usingCustomLocation: Bool, latitude: Double?, longitude: Double?)
    /// A search finished. `firstRouteSeconds` is the wait until the first
    /// route appeared (nil if none), `totalSeconds` the whole search, and
    /// `stoppedEarly` is true when the time cap ended a slow search.
    /// `closestOnly` is true when no loop of the asked length existed and
    /// the list shows the closest matches instead.
    /// `locked` is how many of the `count` loops were shown locked (free tier).
    case routeGenerated(count: Int, minutes: Int, firstRouteSeconds: Double?, totalSeconds: Double, stoppedEarly: Bool, closestOnly: Bool, locked: Int)
    /// A search ended without routes to show: `reason` is one of
    /// `no_routes`, `location_unavailable`, `generation_error`. Cancelled
    /// searches (the user left the screen) are not reported at all.
    /// `detail` says what the generator hit (e.g. `http_422_NoSegment:8`,
    /// `not_converged:6,water:2`); nil when not applicable. Coordinates as
    /// in `routeSearchStarted`.
    case routeSearchFailed(minutes: Int, reason: String, detail: String?, latitude: Double?, longitude: Double?)
    case routeSelected(routeId: UUID, durationMinutes: Int, distanceKm: Double)
    /// The route detail screen was left without starting a walk.
    case routeDismissed(routeId: UUID, secondsOnScreen: Double, saved: Bool)
    /// A route was bookmarked / un-bookmarked. `source`: route_detail, finish_walk, saved_routes.
    case routeSaved(routeId: UUID, source: String)
    case routeUnsaved(routeId: UUID, source: String)
    case walkStarted(routeId: UUID, plannedMinutes: Int, plannedDistanceKm: Double)
    case walkCompleted(
        routeId: UUID,
        durationSeconds: TimeInterval,
        distanceMeters: Double,
        stepCount: Int,
        /// False when Motion & Fitness is denied — a zero `stepCount` then
        /// means "no permission", not "no steps".
        motionAuthorized: Bool,
        plannedMinutes: Int?,
        flipCount: Int,
        rerouteCount: Int
    )
    /// The user accepted the wrong-way prompt and the route was reversed.
    case routeFlipped(routeId: UUID)
    case poiViewed(poiId: UUID, category: String)
    case bookingLinkTapped(poiId: UUID, partner: String)
    case routeShared(routeId: UUID, platform: String)
    case gpxExported(routeId: UUID, pointCount: Int)
    case feedbackSubmitted(rating: Int, tags: [String])
    /// The system App Store rating sheet was requested after a finished
    /// walk. iOS decides whether it actually shows, so this counts asks,
    /// not ratings. `walkCount` is the user's total finished walks.
    case appReviewRequested(walkCount: Int)
    /// `source` is a `PaywallSource` raw value: where the paywall was opened.
    case paywallShown(source: String)
    /// The paywall closed without a purchase or restore.
    case paywallDismissed(source: String)
    /// A free user tapped something Pro-only: `feature` is `locked_route`
    /// or `food`.
    case lockedFeatureTapped(feature: String)
    /// An intro page was shown (`page` 1–3), and how the intro ended.
    case onboardingPageViewed(page: Int)
    case onboardingCompleted(skipped: Bool, lastPage: Int)
    /// The sign-in sheet was offered: `reason` is what asked for it
    /// (save_route, share, feedback, settings, after_walk).
    case accountPromptShown(reason: String)
    /// Sign-in finished: `method` apple or google, `reason` as above.
    case signInCompleted(method: String, reason: String)
    /// The location permission answer after the system prompt:
    /// `status` granted, denied or restricted.
    case locationPermission(status: String)
    /// A purchase completed on the paywall and `looopr_pro` became active.
    /// `price` is the store price of the product in `currency` (what the
    /// user will be charged per period once any trial ends); `periodType`
    /// is "trial", "intro" or "normal" for the period that just started, so
    /// a trial contributes nothing to MRR until it converts. `isSandbox`
    /// marks TestFlight/sandbox purchases so reporting can exclude them.
    case subscriptionStarted(
        productId: String,
        plan: String,
        price: Double?,
        currency: String?,
        periodType: String,
        isSandbox: Bool
    )
    /// Restore Purchases re-activated `looopr_pro` on this account. Not new
    /// revenue — tracked separately so it is never counted as a sale.
    case subscriptionRestored(productId: String, plan: String, isSandbox: Bool)
    /// The off-route detector confirmed the user is `distanceMeters` from
    /// the active route (after the hold time).
    case offRouteDetected(routeId: UUID, distanceMeters: Double)
    /// A reroute was applied. `number` counts reroutes in this walk,
    /// `secondsSinceLast` is nil for the first, `afterFlip` is true when a
    /// wrong-way flip happened since the previous reroute, `reentry` is
    /// smart (forward-facing intersection) or fallback (80 m ahead), and
    /// `trigger` is auto (off-route) or manual ("Guide me back").
    case rerouteTriggered(routeId: UUID, number: Int, distanceMeters: Double?, secondsSinceLast: Double?, afterFlip: Bool, reentry: String, trigger: String)
    /// Automatic rerouting was paused after `reroutes` reroutes in a short
    /// time: the user is going their own way and gets a banner instead.
    case reroutePaused(routeId: UUID, reroutes: Int, secondsSinceWalkStart: Double)
    /// The user ended the walk without finishing it (progress not saved to
    /// history). Not emitted when the app is just closed.
    case walkEndedEarly(routeId: UUID, durationSeconds: TimeInterval, distanceMeters: Double, rerouteCount: Int, flipCount: Int, reroutesPaused: Bool)

    /// Stable event name stored in the `event` column.
    var name: String {
        switch self {
        case .appOpened:           return "app_opened"
        case .routeSearchStarted:  return "route_search_started"
        case .routeGenerated:      return "route_generated"
        case .routeDismissed:      return "route_dismissed"
        case .routeSaved:          return "route_saved"
        case .routeUnsaved:        return "route_unsaved"
        case .routeSearchFailed:   return "route_search_failed"
        case .routeSelected:       return "route_selected"
        case .walkStarted:         return "walk_started"
        case .walkCompleted:       return "walk_completed"
        case .routeFlipped:        return "route_flipped"
        case .poiViewed:           return "poi_viewed"
        case .bookingLinkTapped:   return "booking_link_tapped"
        case .routeShared:         return "route_shared"
        case .gpxExported:         return "gpx_exported"
        case .feedbackSubmitted:   return "feedback_submitted"
        case .appReviewRequested:  return "app_review_requested"
        case .paywallShown:        return "paywall_shown"
        case .paywallDismissed:    return "paywall_dismissed"
        case .lockedFeatureTapped: return "locked_feature_tapped"
        case .onboardingPageViewed: return "onboarding_page_viewed"
        case .onboardingCompleted: return "onboarding_completed"
        case .accountPromptShown:  return "account_prompt_shown"
        case .signInCompleted:     return "sign_in_completed"
        case .locationPermission:  return "location_permission"
        case .subscriptionStarted: return "subscription_started"
        case .subscriptionRestored: return "subscription_restored"
        case .offRouteDetected:    return "off_route_detected"
        case .rerouteTriggered:    return "reroute_triggered"
        case .reroutePaused:       return "reroute_paused"
        case .walkEndedEarly:      return "walk_ended_early"
        }
    }

    /// Structured payload stored in the `properties` jsonb column.
    var properties: [String: AnalyticsValue] {
        switch self {
        case .appOpened:
            return [:]
        case .routeSearchStarted(let minutes, let custom, let latitude, let longitude):
            var props: [String: AnalyticsValue] = ["minutes": .int(minutes), "custom_location": .bool(custom)]
            Self.addCoarseLocation(latitude, longitude, to: &props)
            return props
        case .routeGenerated(let count, let minutes, let firstRouteSeconds, let totalSeconds, let stoppedEarly, let closestOnly, let locked):
            var props: [String: AnalyticsValue] = [
                "count": .int(count),
                "locked": .int(locked),
                "minutes": .int(minutes),
                "total_seconds": .double((totalSeconds * 10).rounded() / 10),
                "stopped_early": .bool(stoppedEarly),
                "closest_only": .bool(closestOnly)
            ]
            if let firstRouteSeconds { props["first_route_seconds"] = .double((firstRouteSeconds * 10).rounded() / 10) }
            return props
        case .routeDismissed(let routeId, let secondsOnScreen, let saved):
            return [
                "route_id": .string(routeId.uuidString),
                "seconds_on_screen": .double((secondsOnScreen * 10).rounded() / 10),
                "saved": .bool(saved)
            ]
        case .routeSaved(let routeId, let source), .routeUnsaved(let routeId, let source):
            return ["route_id": .string(routeId.uuidString), "source": .string(source)]
        case .routeSearchFailed(let minutes, let reason, let detail, let latitude, let longitude):
            var props: [String: AnalyticsValue] = ["minutes": .int(minutes), "reason": .string(reason)]
            if let detail { props["detail"] = .string(String(detail.prefix(120))) }
            Self.addCoarseLocation(latitude, longitude, to: &props)
            return props
        case .routeSelected(let routeId, let duration, let distanceKm):
            return [
                "route_id": .string(routeId.uuidString),
                "duration_minutes": .int(duration),
                "distance_km": .double(distanceKm)
            ]
        case .walkStarted(let routeId, let plannedMinutes, let plannedKm):
            return [
                "route_id": .string(routeId.uuidString),
                "planned_minutes": .int(plannedMinutes),
                "planned_distance_km": .double(plannedKm)
            ]
        case .walkCompleted(let routeId, let duration, let distance, let steps, let motionAuthorized, let planned, let flips, let reroutes):
            var props: [String: AnalyticsValue] = [
                "route_id": .string(routeId.uuidString),
                "duration_seconds": .double(duration),
                "distance_meters": .double(distance),
                "step_count": .int(steps),
                "motion_authorized": .bool(motionAuthorized),
                "flip_count": .int(flips),
                "reroute_count": .int(reroutes)
            ]
            if let planned { props["planned_minutes"] = .int(planned) }
            return props
        case .routeFlipped(let routeId):
            return ["route_id": .string(routeId.uuidString)]
        case .poiViewed(let poiId, let category):
            return ["poi_id": .string(poiId.uuidString), "category": .string(category)]
        case .bookingLinkTapped(let poiId, let partner):
            return ["poi_id": .string(poiId.uuidString), "partner": .string(partner)]
        case .routeShared(let routeId, let platform):
            return ["route_id": .string(routeId.uuidString), "platform": .string(platform)]
        case .gpxExported(let routeId, let pointCount):
            return ["route_id": .string(routeId.uuidString), "point_count": .int(pointCount)]
        case .feedbackSubmitted(let rating, let tags):
            return ["rating": .int(rating), "tags": .stringArray(tags)]
        case .appReviewRequested(let walkCount):
            return ["walk_count": .int(walkCount)]
        case .paywallShown(let source), .paywallDismissed(let source):
            return ["source": .string(source)]
        case .lockedFeatureTapped(let feature):
            return ["feature": .string(feature)]
        case .onboardingPageViewed(let page):
            return ["page": .int(page)]
        case .onboardingCompleted(let skipped, let lastPage):
            return ["skipped": .bool(skipped), "last_page": .int(lastPage)]
        case .accountPromptShown(let reason):
            return ["reason": .string(reason)]
        case .signInCompleted(let method, let reason):
            return ["method": .string(method), "reason": .string(reason)]
        case .locationPermission(let status):
            return ["status": .string(status)]
        case .subscriptionStarted(let productId, let plan, let price, let currency, let periodType, let isSandbox):
            var props: [String: AnalyticsValue] = [
                "product_id": .string(productId),
                "plan": .string(plan),
                "period_type": .string(periodType),
                "is_sandbox": .bool(isSandbox)
            ]
            if let price { props["price"] = .double(price) }
            if let currency { props["currency"] = .string(currency) }
            return props
        case .subscriptionRestored(let productId, let plan, let isSandbox):
            return [
                "product_id": .string(productId),
                "plan": .string(plan),
                "is_sandbox": .bool(isSandbox)
            ]
        case .offRouteDetected(let routeId, let distanceMeters):
            return ["route_id": .string(routeId.uuidString), "distance_meters": .double(distanceMeters.rounded())]
        case .rerouteTriggered(let routeId, let number, let distanceMeters, let secondsSinceLast, let afterFlip, let reentry, let trigger):
            var props: [String: AnalyticsValue] = [
                "route_id": .string(routeId.uuidString),
                "number": .int(number),
                "after_flip": .bool(afterFlip),
                "reentry": .string(reentry),
                "trigger": .string(trigger)
            ]
            if let distanceMeters { props["distance_meters"] = .double(distanceMeters.rounded()) }
            if let secondsSinceLast { props["seconds_since_last"] = .double(secondsSinceLast.rounded()) }
            return props
        case .reroutePaused(let routeId, let reroutes, let secondsSinceWalkStart):
            return [
                "route_id": .string(routeId.uuidString),
                "reroutes": .int(reroutes),
                "seconds_since_walk_start": .double(secondsSinceWalkStart.rounded())
            ]
        case .walkEndedEarly(let routeId, let durationSeconds, let distanceMeters, let rerouteCount, let flipCount, let reroutesPaused):
            return [
                "route_id": .string(routeId.uuidString),
                "duration_seconds": .double(durationSeconds.rounded()),
                "distance_meters": .double(distanceMeters.rounded()),
                "reroute_count": .int(rerouteCount),
                "flip_count": .int(flipCount),
                "reroutes_paused": .bool(reroutesPaused)
            ]
        }
    }

    /// Rounds to 2 decimals (~1.1 km) before anything leaves the device.
    static func coarse(_ value: Double) -> Double { (value * 100).rounded() / 100 }

    private static func addCoarseLocation(_ latitude: Double?, _ longitude: Double?, to props: inout [String: AnalyticsValue]) {
        guard let latitude, let longitude, latitude.isFinite, longitude.isFinite else { return }
        props["lat"] = .double(coarse(latitude))
        props["lon"] = .double(coarse(longitude))
    }
}
