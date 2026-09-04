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
    case routeSelected(routeId: UUID, durationMinutes: Int, distanceKm: Double)
    case walkStarted(routeId: UUID, plannedMinutes: Int, plannedDistanceKm: Double)
    case walkCompleted(
        routeId: UUID,
        durationSeconds: TimeInterval,
        distanceMeters: Double,
        stepCount: Int,
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
    case subscriptionStarted
    case offRouteDetected(routeId: UUID)
    case rerouteTriggered(routeId: UUID)

    /// Stable event name stored in the `event` column.
    var name: String {
        switch self {
        case .appOpened:           return "app_opened"
        case .routeSearchStarted:  return "route_search_started"
        case .routeGenerated:      return "route_generated"
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
        case .walkCompleted(let routeId, let duration, let distance, let steps, let planned, let flips, let reroutes):
            var props: [String: AnalyticsValue] = [
                "route_id": .string(routeId.uuidString),
                "duration_seconds": .double(duration),
                "distance_meters": .double(distance),
                "step_count": .int(steps),
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
        case .paywallShown, .subscriptionStarted:
            return [:]
        case .offRouteDetected(let routeId), .rerouteTriggered(let routeId):
            return ["route_id": .string(routeId.uuidString)]
        }
    }
}
