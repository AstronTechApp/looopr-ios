import Foundation

struct FeedbackTag: Identifiable, Sendable {
    let id: String
    let label: String
    let icon: String
    let isPositive: Bool

    static let positive: [FeedbackTag] = [
        FeedbackTag(id: "great_scenery", label: "Great scenery", icon: "eye.fill", isPositive: true),
        FeedbackTag(id: "nice_cafes", label: "Nice cafes", icon: "cup.and.saucer.fill", isPositive: true),
        FeedbackTag(id: "good_sidewalks", label: "Good sidewalks", icon: "figure.walk", isPositive: true),
        FeedbackTag(id: "quiet_streets", label: "Quiet streets", icon: "leaf.fill", isPositive: true),
        FeedbackTag(id: "beautiful_architecture", label: "Beautiful architecture", icon: "building.columns.fill", isPositive: true),
    ]

    static let negative: [FeedbackTag] = [
        FeedbackTag(id: "too_crowded", label: "Too crowded", icon: "person.3.fill", isPositive: false),
        FeedbackTag(id: "bad_sidewalks", label: "Bad sidewalks", icon: "exclamationmark.triangle.fill", isPositive: false),
        FeedbackTag(id: "felt_unsafe", label: "Felt unsafe", icon: "shield.slash.fill", isPositive: false),
        FeedbackTag(id: "too_noisy", label: "Too noisy", icon: "speaker.wave.3.fill", isPositive: false),
        FeedbackTag(id: "boring_area", label: "Boring area", icon: "moon.zzz.fill", isPositive: false),
    ]

    static let all: [FeedbackTag] = positive + negative
}
