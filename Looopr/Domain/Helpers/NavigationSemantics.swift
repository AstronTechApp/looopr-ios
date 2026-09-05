import Foundation

/// Language-independent reading of a navigation step.
///
/// Mapbox steps carry a structured `maneuver.type` / `maneuver.modifier` and a
/// street `name`, so the turn arrow, arrival detection and the street line do
/// not depend on the instruction's language. Steps that come from MapKit
/// (reroutes, detours) only have localized text, so a keyword fallback covers
/// English and Dutch — the two languages Looopr ships with at launch.
enum NavigationSemantics {
    enum Turn {
        case uturn, sharpLeft, sharpRight, slightLeft, slightRight
        case left, right, straight, roundabout, arrive
    }

    // MARK: - Reading a step

    static func turn(for step: NavigationStep) -> Turn? {
        turn(instruction: step.instruction, modifier: step.maneuverModifier, type: step.maneuverType)
    }

    static func turn(instruction: String, modifier: String? = nil, type: String? = nil) -> Turn? {
        if let type = type?.lowercased() {
            if type == "arrive" { return .arrive }
            if type.contains("roundabout") || type.contains("rotary") { return .roundabout }
        }
        if let modifier = modifier?.lowercased() {
            switch modifier {
            case "uturn": return .uturn
            case "sharp left": return .sharpLeft
            case "sharp right": return .sharpRight
            case "slight left": return .slightLeft
            case "slight right": return .slightRight
            case "left": return .left
            case "right": return .right
            case "straight": return .straight
            default: break
            }
        }
        return turn(fromText: instruction)
    }

    /// Keyword fallback for steps without structured data. English and Dutch.
    static func turn(fromText text: String) -> Turn? {
        let lower = text.lowercased()
        func has(_ words: String...) -> Bool { words.contains { lower.contains($0) } }

        if has("u-turn", "u turn", "uturn", "keer om", "omkeren") { return .uturn }
        if has("sharp left", "hard left", "sharply left", "scherp links", "scherpe bocht naar links") { return .sharpLeft }
        if has("sharp right", "hard right", "sharply right", "scherp rechts", "scherpe bocht naar rechts") { return .sharpRight }
        if has("slight left", "bear left", "keep left", "flauw links", "links aanhouden", "iets naar links") { return .slightLeft }
        if has("slight right", "bear right", "keep right", "flauw rechts", "rechts aanhouden", "iets naar rechts") { return .slightRight }
        if has("arrive", "arriving", "arrived", "destination", "you have reached", "end of route",
               "bestemming", "aangekomen", "eindpunt", "u bent gearriveerd", "je bent er") { return .arrive }
        if has("roundabout", "rotary", "rotonde") { return .roundabout }
        if has("left", "links") { return .left }
        if has("right", "rechts") { return .right }
        if has("straight", "continue", "head ", "rechtdoor", "ga verder", "loop richting", "vervolg") { return .straight }
        return nil
    }

    static func isArrival(_ step: NavigationStep) -> Bool {
        turn(for: step) == .arrive
    }

    static func isArrival(instruction: String) -> Bool {
        turn(fromText: instruction) == .arrive
    }

    // MARK: - Presentation

    /// SF Symbol for the turn card.
    static func sfSymbol(for turn: Turn?) -> String {
        switch turn {
        case .sharpLeft, .left: return "arrow.turn.up.left"
        case .sharpRight, .right: return "arrow.turn.up.right"
        case .slightLeft: return "arrow.up.left"
        case .slightRight: return "arrow.up.right"
        case .uturn: return "arrow.uturn.down"
        case .arrive: return "flag.fill"
        case .roundabout: return "arrow.triangle.turn.up.right.circle"
        case .straight, .none: return "arrow.up"
        }
    }

    /// Single-character arrow for the Live Activity.
    static func arrowGlyph(for turn: Turn?) -> String? {
        switch turn {
        case .uturn: return "↩"
        case .sharpLeft: return "↙"
        case .sharpRight: return "↘"
        case .slightLeft: return "↖"
        case .slightRight: return "↗"
        case .left: return "←"
        case .right: return "→"
        case .straight, .roundabout: return "↑"
        case .arrive: return "📍"
        case .none: return nil
        }
    }

    /// The street to show under the distance: the step's street name when the
    /// routing service provided one, otherwise whatever follows "onto"/"naar"
    /// in the instruction, otherwise the whole instruction.
    static func streetLine(for step: NavigationStep) -> String {
        streetLine(instruction: step.instruction, streetName: step.streetName)
    }

    static func streetLine(instruction: String, streetName: String? = nil) -> String {
        if let streetName, !streetName.trimmingCharacters(in: .whitespaces).isEmpty {
            return streetName
        }
        for marker in ["onto ", " naar "] {
            if let range = instruction.range(of: marker, options: .caseInsensitive) {
                let rest = instruction[range.upperBound...].trimmingCharacters(in: .whitespaces)
                if !rest.isEmpty { return rest.trimmingCharacters(in: CharacterSet(charactersIn: ".")) }
            }
        }
        return instruction
    }
}
