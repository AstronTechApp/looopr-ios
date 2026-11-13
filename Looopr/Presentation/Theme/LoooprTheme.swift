//
//  LoooprTheme.swift
//  Looopr
//
//  Design System — single source of truth for all UI tokens.
//  Creative North Star: "The Living Trail" — Organic Editorial aesthetic.
//
//  Usage:
//    Text("Hello").foregroundColor(LoooprTheme.Colors.primary)
//    .padding(LoooprTheme.Spacing.md)
//    .cornerRadius(LoooprTheme.Radius.card)
//

import SwiftUI

// MARK: - Theme Namespace

enum LoooprTheme {}

// MARK: - Colors

extension LoooprTheme {

    enum Colors {

        // ── Brand (Forest & Stone) ────────────────────────────
        /// Forest green — primary CTAs, active states, icons
        static let primary        = Color(light: "#176a21", dark: "#3a9a46")
        /// Leaf green — selected card backgrounds, chips
        static let primaryLight   = Color(light: "#9df197", dark: "#1f3a22")
        /// Forest pressed/dark state
        static let primaryDark    = Color(light: "#025d16", dark: "#2e8b3a")

        // ── Secondary (Action Orange) ────────────────────────
        /// Warm orange — urgency, highlights, food markers
        static let secondary      = Color(light: "#9b3f00", dark: "#ffb48f")
        /// Orange tint — secondary containers
        static let secondaryContainer = Color(light: "#ffc5aa", dark: "#4a2410")

        // ── Tertiary (Sky Blue) ──────────────────────────────
        /// Blue — GPS interactive, toggle states
        static let tertiary       = Color(light: "#006096", dark: "#8ccdff")
        /// Blue tint — info containers
        static let tertiaryContainer = Color(light: "#5fb7ff", dark: "#0b4a72")

        // ── Backgrounds (Surface Hierarchy) ──────────────────
        /// Base — cool off-white
        static let background     = Color(light: "#f5f7f3", dark: "#111512")
        /// Topmost card layer — crisp white lift
        static let surface        = Color(light: "#FFFFFF", dark: "#1b201c")
        /// Deepest recess — secondary background
        static let surfaceSecondary = Color(light: "#eff1ed", dark: "#222823")
        /// Main interactive zones
        static let surfaceContainer = Color(light: "#e6e9e5", dark: "#2a302b")
        /// High-contrast surface
        static let surfaceContainerHigh = Color(light: "#e0e3df", dark: "#333a34")
        /// Soft green wash for a tappable row or callout on a surface
        static let surfaceTint    = Color(light: "#eef5ea", dark: "#222b24")

        // ── Text ───────────────────────────────────────────────
        /// Headings, primary labels
        static let textPrimary    = Color(light: "#2c2f2d", dark: "#e4e8e3")
        /// Subtitles, metadata
        static let textSecondary  = Color(light: "#595c59", dark: "#b4bab3")
        /// Placeholders, inactive tabs
        static let textTertiary   = Color(light: "#abaeaa", dark: "#8a9089")
        /// Text on green buttons
        static let textOnPrimary  = Color(light: "#d1ffc8", dark: "#f0fff0")

        // ── Borders & Dividers ─────────────────────────────────
        /// Ghost border — outline-variant at 15% (per design spec)
        static let border         = Color(light: "#abaeaa", dark: "#ffffff", lightOpacity: 0.15, darkOpacity: 0.10)
        /// Stronger outline
        static let borderStrong   = Color(light: "#747875", dark: "#8c918b")

        // ── Navigation ─────────────────────────────────────────
        static let navBackground  = Color(light: "#FFFFFF", dark: "#1b201c")
        static let navActive      = Color(light: "#176a21", dark: "#3a9a46")
        static let navInactive    = Color(light: "#abaeaa", dark: "#8a9089")

        // ── Status ─────────────────────────────────────────────
        static let success        = Color(light: "#176a21", dark: "#3a9a46")
        static let error          = Color(light: "#b02500", dark: "#ff8f73")
        static let warning        = Color(hex: "#F0A500")

        // ── Map / Walk ─────────────────────────────────────────
        /// Route path drawn on map
        static let routeLine      = Color(hex: "#0288D1")
        /// Endpoint dot / POI marker — warm accent
        static let routeDot       = Color(hex: "#c45a2d")

        // ── Text on tinted containers (badges, chips) ─────────
        /// Text on `primaryLight` chips (e.g. "Saved", "Easy" badges).
        static let onPrimaryContainer   = Color(light: "#005c15", dark: "#b6f2b0")
        /// Text on `secondaryContainer` chips (e.g. the walk length chip).
        static let onSecondaryContainer = Color(light: "#7b3100", dark: "#ffd2bd")
        /// Informational notices (ferry crossings).
        static let info                 = Color(light: "#0D47A1", dark: "#a8cfff")
        static let infoContainer        = Color(light: "#BBDEFB", dark: "#15324d")

        // ── Overlays ───────────────────────────────────────────
        static let overlay        = Color.black.opacity(0.4)
        static let overlayLight   = Color(light: "#ffffff", dark: "#1b201c", lightOpacity: 0.85, darkOpacity: 0.85)
        static let mapOverlay     = Color.black.opacity(0.3)
    }
}

// MARK: - Typography

extension LoooprTheme {

    enum Typography {

        // ── Font sizes ─────────────────────────────────────────
        static let xs:   CGFloat = 11
        static let sm:   CGFloat = 13
        static let base: CGFloat = 15
        static let md:   CGFloat = 17
        static let lg:   CGFloat = 20
        static let xl:   CGFloat = 24
        static let xxl:  CGFloat = 28
        static let xxxl: CGFloat = 34

        // ── Named text styles ──────────────────────────────────
        /// Large screen titles
        static var largeTitle: Font { .system(size: xxxl, weight: .bold, design: .rounded) }
        /// Section headings
        static var title: Font     { .system(size: xl,   weight: .bold, design: .rounded) }
        /// Card titles, route names
        static var headline: Font  { .system(size: md,   weight: .semibold, design: .rounded) }
        /// Body copy
        static var body: Font      { .system(size: base, weight: .regular, design: .rounded) }
        /// Subtitles, metadata rows
        static var subheadline: Font { .system(size: sm, weight: .medium, design: .rounded) }
        /// Captions, tags, nav labels
        static var caption: Font   { .system(size: xs,   weight: .medium, design: .rounded) }
        /// CTA button labels
        static var button: Font    { .system(size: md,   weight: .semibold, design: .rounded) }
        /// Uppercase section labels (e.g. "TEMPLATE")
        static var label: Font     { .system(size: xs,   weight: .semibold, design: .rounded) }
    }
}

// MARK: - Spacing

extension LoooprTheme {

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs:  CGFloat = 8
        static let sm:  CGFloat = 12
        static let md:  CGFloat = 16
        static let lg:  CGFloat = 20
        static let xl:  CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 40
        static let xxxxl: CGFloat = 48
        static let huge: CGFloat = 64

        /// Standard horizontal screen padding
        static let screenHorizontal: CGFloat = 20
        /// Gap between cards in a list
        static let cardGap: CGFloat = 12
    }
}

// MARK: - Border Radius

extension LoooprTheme {

    enum Radius {
        static let sm:   CGFloat = 8
        static let md:   CGFloat = 12
        static let lg:   CGFloat = 16
        static let xl:   CGFloat = 20
        static let xxl:  CGFloat = 28
        static let full: CGFloat = 9999

        // Semantic aliases
        /// Full pill — primary buttons, chips
        static let button: CGFloat = 9999
        /// Route cards, template cards
        static let card:   CGFloat = 16
        /// Bottom sheet top corners
        static let sheet:  CGFloat = 20
        /// Text inputs
        static let input:  CGFloat = 12
        /// Photo collage cells
        static let photo:  CGFloat = 12
        /// Tag chips, segmented control
        static let chip:   CGFloat = 9999
    }
}

// MARK: - Shadows

extension LoooprTheme {

    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    enum Shadows {
        static let none   = ShadowStyle(color: .clear,                       radius: 0,  x: 0, y: 0)
        /// Tinted ambient — nature has ambient light, not black shadows
        static let sm     = ShadowStyle(color: Color(hex: "#90e28a").opacity(0.06), radius: 4,  x: 0, y: 1)
        static let md     = ShadowStyle(color: Color(hex: "#90e28a").opacity(0.08), radius: 8,  x: 0, y: 2)
        static let lg     = ShadowStyle(color: Color(hex: "#90e28a").opacity(0.10), radius: 16, x: 0, y: 4)
        /// Bottom sheet upward shadow
        static let sheet  = ShadowStyle(color: Color(hex: "#176a21").opacity(0.08), radius: 12, x: 0, y: -2)
        /// Card hover/lift state — diffuse green-tinted
        static let card   = ShadowStyle(color: Color(hex: "#176a21").opacity(0.12), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Layout Constants

extension LoooprTheme {

    enum Layout {
        static let headerHeight:         CGFloat = 56
        static let navBarHeight:         CGFloat = 80   // floating pill (56) + bottom margin (16) + gap (8)
        static let navBarContentHeight:  CGFloat = 56   // pill height

        // Bottom sheet heights
        static let sheetPeekHeight:      CGFloat = 120  // collapsed
        static let sheetDefaultFraction: CGFloat = 0.45 // 45% of screen
        static let sheetExpandedFraction: CGFloat = 0.85 // 85% of screen

        // Template card size (collage editor)
        static let templateCardSize:     CGFloat = 100

        // Route card
        static let routeCardImageHeight: CGFloat = 200
    }
}

// MARK: - Animation

extension LoooprTheme {

    enum Animation {
        static let fast:   Double = 0.15
        static let normal: Double = 0.25
        static let slow:   Double = 0.40

        static var standard: SwiftUI.Animation {
            .spring(response: 0.35, dampingFraction: 0.75)
        }
        static var gentle: SwiftUI.Animation {
            .spring(response: 0.5, dampingFraction: 0.85)
        }
        static var snappy: SwiftUI.Animation {
            .spring(response: 0.25, dampingFraction: 0.7)
        }
    }
}

// MARK: - SwiftUI View Modifiers

/// Apply a LoooprTheme shadow style in one call:
///   .loooprShadow(.md)
extension View {

    func loooprShadow(_ style: LoooprTheme.ShadowStyle) -> some View {
        self.shadow(
            color: style.color,
            radius: style.radius,
            x: style.x,
            y: style.y
        )
    }

    /// Standard screen horizontal padding
    func screenPadding() -> some View {
        self.padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
    }
}

// MARK: - Primary Button Style

struct LoooprPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .heavy, design: .rounded))
            .tracking(-0.3)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#1B5E20"), Color(hex: "#66BB6A")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(configuration.isPressed ? 0.85 : 1.0)
            )
            .clipShape(Capsule())
            .shadow(color: LoooprTheme.Colors.primary.opacity(0.2), radius: 12, y: 6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(LoooprTheme.Animation.snappy, value: configuration.isPressed)
    }
}

/// Usage: Button("Start Walk") { }.buttonStyle(LoooprPrimaryButtonStyle())
extension ButtonStyle where Self == LoooprPrimaryButtonStyle {
    static var loooprPrimary: LoooprPrimaryButtonStyle { .init() }
}

// MARK: - Secondary Button Style

struct LoooprSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LoooprTheme.Typography.button)
            .foregroundColor(LoooprTheme.Colors.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(LoooprTheme.Colors.primaryLight)
            .cornerRadius(LoooprTheme.Radius.button)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(LoooprTheme.Animation.snappy, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == LoooprSecondaryButtonStyle {
    static var loooprSecondary: LoooprSecondaryButtonStyle { .init() }
}

// MARK: - Color Hex Initialiser

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255,
                            (int >> 8) * 17,
                            (int >> 4 & 0xF) * 17,
                            (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255,
                            int >> 16,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24,
                            int >> 16 & 0xFF,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red:     Double(r) / 255,
            green:   Double(g) / 255,
            blue:    Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Light / dark colours

extension Color {
    /// A colour that follows the system appearance: `light` in light mode,
    /// `dark` in dark mode. Every theme colour is built this way since 1.5.
    init(light: String, dark: String, lightOpacity: Double = 1, darkOpacity: Double = 1) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark).opacity(darkOpacity))
                : UIColor(Color(hex: light).opacity(lightOpacity))
        })
    }
}
