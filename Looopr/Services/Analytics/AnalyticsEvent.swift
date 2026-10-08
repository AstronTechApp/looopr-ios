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
    case routeSearchStarted(minutes: Int, usingCustomLocation: Bool)
    case routeGenerated(count: Int, minutes: Int)
    /// A search ended without routes to show: `reason` is one of
    /// `no_routes`, `location_unavailable`, `generation_error`. Cancelled
    /// searches (the user left the screen) are not reported at all.
    case routeSearchFailed(minutes: Int, reason: String)
    case routeSelected(routeId: UUID, durationMinutes: Int, distanceKm: Double)
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
    case paywallShown
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
    case offRouteDetected(routeId: UUID)
    case rerouteTriggered(routeId: UUID)

    /// Stable event name stored in the `event` column.
    var name: String {
        switch self {
        case .appOpened:           return "app_opened"
        case .routeSearchStarted:  return "route_search_started"
        case .routeGenerated:      return "route_generated"
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
        case .paywallShown:        return "paywall_shown"
        case .subscriptionStarted: return "subscription_started"
        case .subscriptionRestored: return "subscription_restored"
        case .offRouteDetected:    return "off_route_detected"
        case .rerouteTriggered:    return "reroute_triggered"
        }
    }

    /// Structured payload stored in the `properties` jsonb column.
    var properties: [String: AnalyticsValue] {
        switch self {
        case .appOpened:
            return [:]
        case .routeSearchStarted(let minutes, let custom):
            return ["minutes": .int(minutes), "custom_location": .bool(custom)]
        case .routeGenerated(let count, let minutes):
            return ["count": .int(count), "minutes": .int(minutes)]
        case .routeSearchFailed(let minutes, let reason):
            return ["minutes": .int(minutes), "reason": .string(reason)]
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
        case .paywallShown:
            return [:]
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
        case .offRouteDetected(let routeId), .rerouteTriggered(let routeId):
            return ["route_id": .string(routeId.uuidString)]
        }
    }
}
