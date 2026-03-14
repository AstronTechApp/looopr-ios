import SwiftUI

enum AppTheme {
    // MARK: - Colors
    static let primary = Color.blue
    static let secondary = Color.orange
    static let background = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)

    static let routeColors: [Color] = [
        .blue, .green, .orange, .purple, .red, .teal, .indigo, .pink
    ]

    static func routeColor(for index: Int) -> Color {
        routeColors[index % routeColors.count]
    }

    // MARK: - Typography
    static let titleFont = Font.title2.bold()
    static let headlineFont = Font.headline
    static let bodyFont = Font.body
    static let captionFont = Font.caption

    // MARK: - Spacing
    static let spacingSmall: CGFloat = 8
    static let spacingMedium: CGFloat = 16
    static let spacingLarge: CGFloat = 24

    // MARK: - Corner Radius
    static let cornerRadius: CGFloat = 12
    static let cornerRadiusSmall: CGFloat = 8
}
