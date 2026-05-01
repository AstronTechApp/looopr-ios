import Foundation

// MARK: - Opening Hours

/// Extracts the selected day's opening hours from Google Places `weekday_text` array.
///
/// Google Places `weekday_text` uses index 0 = Monday ... 6 = Sunday.
/// `Calendar.current.component(.weekday, from:)` returns 1 = Sunday ... 7 = Saturday.
///
/// Returns e.g. "Today: 9:00 am - 5:00 pm" or "Today: Closed".
/// Returns nil if the input is nil/empty or the index is out of range.
func todayHoursString(from weekdayText: [String]?, at date: Date = Date()) -> String? {
    guard let weekdayText, !weekdayText.isEmpty else { return nil }
    let googleIndex = weekdayTextIndex(for: date)
    guard googleIndex < weekdayText.count else { return nil }

    let raw = weekdayText[googleIndex]
    // Strip day name prefix (e.g. "Monday:") and replace with "Today:"
    if let colonRange = raw.range(of: ":") {
        let timePart = raw[colonRange.upperBound...].trimmingCharacters(in: .whitespaces)
        if Calendar.current.isDateInToday(date) {
            return "Today: \(timePart)"
        }
    }
    return raw
}

// MARK: - Open Status

/// Represents the current opening status of a POI.
enum OpenStatus: Sendable, Equatable {
    case open
    case openingSoon   // closed now but opens within 30 min
    case closed
    case unknown       // no opening hours data available
}

/// Determines the open status of a POI based on its `isOpenNow` flag
/// and optional weekday hours text.
///
/// - Food POIs (no `weekdayText`): Uses `isOpenNow` only — no "opening soon" detection.
/// - Enriched attractions (with `weekdayText`): Can detect "opening soon" by parsing
///   today's opening time and comparing to the current time.
/// - POIs with no hours data at all: Returns `.unknown` so they remain visible.
func poiOpenStatus(
    isOpenNow: Bool?,
    weekdayText: [String]?,
    periods: [OpeningHoursPeriod]? = nil,
    at date: Date? = nil
) -> OpenStatus {
    if let date {
        if let periods, !periods.isEmpty {
            return isOpen(at: date, periods: periods) ? .open : .closed
        }
        if let weekdayText, !weekdayText.isEmpty {
            return isOpen(at: date, weekdayText: weekdayText) ? .open : .closed
        }
        return .unknown
    }

    if let isOpenNow {
        if isOpenNow { return .open }

        // Place is currently closed — check if it's opening soon.
        if isOpeningSoon(within: 30, weekdayText: weekdayText) {
            return .openingSoon
        }
        return .closed
    }

    if let periods, !periods.isEmpty {
        return isOpen(at: Date(), periods: periods) ? .open : .closed
    }

    return .unknown
}

/// Returns `true` if the place is currently closed but opens within
/// the given number of minutes, based on today's weekday hours text.
///
/// Returns `false` if hours can't be parsed, today is "Closed",
/// or the format is unexpected.
func isOpeningSoon(within minutes: Int, weekdayText: [String]?) -> Bool {
    guard let weekdayText, !weekdayText.isEmpty else { return false }

    let googleIndex = weekdayTextIndex(for: Date())
    guard googleIndex < weekdayText.count else { return false }

    let raw = weekdayText[googleIndex]

    // Extract the time part after the day name colon (e.g., "Monday: 9:00 AM – 5:00 PM")
    guard let colonRange = raw.range(of: ":") else { return false }
    let timePart = raw[colonRange.upperBound...].trimmingCharacters(in: .whitespaces)

    // Skip "Closed" or "Open 24 hours"
    let lower = timePart.lowercased()
    if lower == "closed" || lower.contains("24 hours") { return false }

    // Extract the opening time (before the dash/en-dash)
    // Formats: "9:00 AM – 5:00 PM", "9:00 am - 5:00 pm", "9:00 AM–5:00 PM"
    let separators: [String] = [" – ", " - ", "–", "-"]
    var openTimeStr: String?
    for sep in separators {
        if let dashRange = timePart.range(of: sep) {
            openTimeStr = String(timePart[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            break
        }
    }
    guard let openTimeStr, !openTimeStr.isEmpty else { return false }

    // Parse the opening time
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")

    // Try common formats
    let formats = ["h:mm a", "h:mm a", "HH:mm", "H:mm"]
    var openingDate: Date?

    for format in formats {
        formatter.dateFormat = format
        if let parsed = formatter.date(from: openTimeStr) {
            openingDate = parsed
            break
        }
    }

    // Also try case-insensitive by uppercasing AM/PM
    if openingDate == nil {
        let normalized = openTimeStr
            .replacingOccurrences(of: "am", with: "AM")
            .replacingOccurrences(of: "pm", with: "PM")
        formatter.dateFormat = "h:mm a"
        openingDate = formatter.date(from: normalized)
    }

    guard let openingDate else { return false }

    // Compare: is the opening time within `minutes` from now?
    let calendar = Calendar.current
    let now = Date()
    let openHour = calendar.component(.hour, from: openingDate)
    let openMinute = calendar.component(.minute, from: openingDate)

    guard let todayOpening = calendar.date(
        bySettingHour: openHour, minute: openMinute, second: 0, of: now
    ) else { return false }

    let diff = todayOpening.timeIntervalSince(now)
    // Opening time is in the future and within the threshold
    return diff > 0 && diff <= Double(minutes * 60)
}

func isOpen(at date: Date, periods: [OpeningHoursPeriod]) -> Bool {
    let calendar = Calendar.current
    let weekday = calendar.component(.weekday, from: date) - 1
    let hour = calendar.component(.hour, from: date)
    let minute = calendar.component(.minute, from: date)
    let targetMinute = weekday * 24 * 60 + hour * 60 + minute
    let minutesPerWeek = 7 * 24 * 60

    return periods.contains { period in
        guard let openDay = period.openDay else { return false }
        guard let closeHour = period.closeHour,
              let closeMinute = period.closeMinute
        else {
            return true
        }

        let openMinute = openDay * 24 * 60 + period.openHour * 60 + period.openMinute
        var closeMinuteOfWeek = (period.closeDay ?? openDay) * 24 * 60 + closeHour * 60 + closeMinute
        var target = targetMinute

        if closeMinuteOfWeek <= openMinute {
            closeMinuteOfWeek += minutesPerWeek
            if target < openMinute {
                target += minutesPerWeek
            }
        }

        return target >= openMinute && target < closeMinuteOfWeek
    }
}

func isOpen(at date: Date, weekdayText: [String]) -> Bool {
    let index = weekdayTextIndex(for: date)
    guard index < weekdayText.count else { return false }

    let raw = weekdayText[index]
    let timePart: String
    if let colonRange = raw.range(of: ":") {
        timePart = String(raw[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
    } else {
        timePart = raw.trimmingCharacters(in: .whitespaces)
    }

    let lower = timePart.lowercased()
    if lower == "closed" { return false }
    if lower.contains("24 hours") { return true }

    let target = Calendar.current.component(.hour, from: date) * 60
        + Calendar.current.component(.minute, from: date)

    return timePart
        .split(separator: ",")
        .contains { rawRange in
            let range = String(rawRange).trimmingCharacters(in: .whitespaces)
            guard let parsed = parseTimeRange(range) else { return false }
            if parsed.close <= parsed.open {
                return target >= parsed.open || target < parsed.close
            }
            return target >= parsed.open && target < parsed.close
        }
}

private func weekdayTextIndex(for date: Date) -> Int {
    // Map Calendar weekday (1=Sun..7=Sat) to Google weekday text index (0=Mon..6=Sun).
    let weekdayComponent = Calendar.current.component(.weekday, from: date)
    return (weekdayComponent + 5) % 7
}

private func parseTimeRange(_ range: String) -> (open: Int, close: Int)? {
    let separators = [" – ", " - ", "–", "-"]
    for separator in separators {
        if let dashRange = range.range(of: separator) {
            let openString = String(range[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let closeString = String(range[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard let open = minutesFromTimeString(openString),
                  let close = minutesFromTimeString(closeString)
            else {
                return nil
            }
            return (open, close)
        }
    }
    return nil
}

private func minutesFromTimeString(_ string: String) -> Int? {
    let normalized = string
        .replacingOccurrences(of: "am", with: "AM")
        .replacingOccurrences(of: "pm", with: "PM")
        .trimmingCharacters(in: .whitespaces)

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")

    for format in ["h:mm a", "h a", "ha", "HH:mm", "H:mm"] {
        formatter.dateFormat = format
        if let parsed = formatter.date(from: normalized) {
            return Calendar.current.component(.hour, from: parsed) * 60
                + Calendar.current.component(.minute, from: parsed)
        }
    }

    return nil
}

// MARK: - Booking CTA

/// Strategy for determining which booking/CTA button to show for a POI.
enum BookingCTAStrategy {
    /// Show "Book on GetYourGuide" primary CTA with provider comparison.
    /// Appropriate for tours, experiences, and museums.
    case getYourGuide

    /// Show "Visit Website" as primary CTA.
    /// For venues that sell tickets directly (cinemas, theaters, stadiums).
    case website

    /// No dedicated booking CTA — website and call only.
    case none
}

// MARK: - Place Description Mapping

/// Maps Google Places `types` array to a human-readable place description.
/// Evaluates types in priority order and returns the first match.
func placeDescription(for types: [String]) -> String {
    let priorityMap: [(String, String)] = [
        // Entertainment (highest priority)
        ("movie_theater",           "Cinema"),
        ("performing_arts_theater", "Theater"),
        ("cinema",                  "Cinema"),

        // Museums & galleries
        ("museum",                  "Museum"),
        ("art_gallery",             "Art Gallery"),

        // Attractions & parks
        ("tourist_attraction",      "Tourist Attraction"),
        ("amusement_park",          "Amusement Park"),
        ("zoo",                     "Zoo"),
        ("aquarium",                "Aquarium"),
        ("park",                    "Park"),
        ("garden",                  "Garden"),

        // Sports & recreation
        ("stadium",                 "Stadium"),
        ("bowling_alley",           "Bowling Alley"),
        ("golf_course",             "Golf Course"),
        ("ski_resort",              "Ski Resort"),
        ("gym",                     "Gym"),

        // Entertainment/nightlife
        ("casino",                  "Casino"),
        ("night_club",              "Night Club"),

        // Food & drink
        ("restaurant",              "Restaurant"),
        ("cafe",                    "Café"),
        ("bar",                     "Bar"),
        ("bakery",                  "Bakery"),
        ("meal_takeaway",           "Food Takeaway"),
        ("meal_delivery",           "Food Delivery"),

        // Worship
        ("church",                  "Church"),
        ("mosque",                  "Mosque"),
        ("hindu_temple",            "Temple"),
        ("synagogue",               "Synagogue"),
        ("place_of_worship",        "Place of Worship"),

        // Cultural & civic
        ("library",                 "Library"),
        ("city_hall",               "City Hall"),
        ("local_government_office", "Government Office"),
        ("university",              "University"),
        ("school",                  "School"),

        // Fallback
        ("point_of_interest",       "Point of Interest"),
        ("establishment",           "Venue"),
    ]

    for (type, label) in priorityMap {
        if types.contains(type) { return label }
    }

    return "Place"
}

// MARK: - Booking CTA Strategy Determination

/// Minimum number of Google Places reviews required before showing a
/// GetYourGuide booking button. Places below this threshold are likely
/// minor landmarks without bookable experiences.
private let minimumReviewsForGYG: Int = 50

/// Determines the appropriate booking/CTA strategy for a POI based on its
/// Google Places types, review count, and name.
func bookingStrategy(for types: [String], reviewCount: Int?, name: String) -> BookingCTAStrategy {
    let typesSet = Set(types)

    // Free / public places — no booking CTA of any kind
    let noBookingTypes: Set<String> = [
        "park",
        "garden",
        "natural_feature",
        "cemetery",
        "locality",
        "sublocality",
        "neighborhood",
        "route",
        "street_address",
        "public_square",
        // Address / geographic subtypes
        "premise",
        "street_number",
        "intersection",
        "political",
        "colloquial_area",
        "ward",
        "subpremise",
        // Religious sites (free to enter in most cases)
        "church",
        "mosque",
        "synagogue",
        "hindu_temple",
        "place_of_worship",
        // Government / civic
        "city_hall",
        "local_government_office",
        "library",
    ]

    // Venues that sell tickets directly — show website, not GYG
    let directBookingTypes: Set<String> = [
        "movie_theater",
        "cinema",
        "performing_arts_theater",
        "stadium",
        "bowling_alley",
        "amusement_park",
        "casino",
        "night_club",
        "golf_course",
        "ski_resort",
        "gym",
    ]

    // GetYourGuide-appropriate types (tours, experiences, cultural attractions)
    let gygTypes: Set<String> = [
        "tourist_attraction",
        "museum",
        "art_gallery",
        "aquarium",
        "zoo",
    ]

    // 1. Free/public places — no booking CTA
    if !typesSet.isDisjoint(with: noBookingTypes) {
        return .none
    }

    // 2. Name-based guard for obvious free public spaces
    if isLikelyFreePublicSpace(name: name) {
        return .none
    }

    // 3. Venues that sell tickets directly — show website, not GYG
    if !typesSet.isDisjoint(with: directBookingTypes) {
        return .website
    }

    // 4. Experience/attraction types — show GYG only if sufficiently reviewed
    if !typesSet.isDisjoint(with: gygTypes) {
        let reviews = reviewCount ?? 0
        // Small independent art galleries rarely have bookable GYG experiences.
        // Only show GYG for art_gallery if it also qualifies as a museum/tourist_attraction
        // (major venues like Rijksmuseum) or has 200+ reviews.
        let majorTypes: Set<String> = ["museum", "tourist_attraction", "aquarium", "zoo"]
        let isArtGalleryOnly = typesSet.contains("art_gallery") && typesSet.isDisjoint(with: majorTypes)
        let threshold = isArtGalleryOnly ? 200 : minimumReviewsForGYG

        if reviews >= threshold {
            return .getYourGuide
        }
        // Not enough reviews — likely a minor landmark; show website only
        return .website
    }

    // 5. Default — website and call only if available
    return .none
}

// MARK: - Free Public Space Detection

/// Returns true if the place name suggests a free, public space that
/// would not have bookable experiences on GetYourGuide.
private func isLikelyFreePublicSpace(name: String) -> Bool {
    let freeSpaceKeywords = [
        // Public squares
        "square", "plein", "platz", "plaza", "piazza",
        // Statues & monuments
        "statue", "standbeeld", "monument",
        // Memorials
        "memorial", "gedenkteken",
        // Bridges
        "bridge", "brug", "pont",
        // Fountains
        "fountain", "fontein",
        // Viewpoints
        "viewpoint", "uitzichtpunt",
        // Street art
        "mural", "muurschildering", "street art", "graffiti",
    ]
    let lowercased = name.lowercased()
    return freeSpaceKeywords.contains { lowercased.contains($0) }
}
