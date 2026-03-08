import SwiftUI

// MARK: - AppColors — single source of truth for every color in the app.
//
// Dark-only token system. No adaptive UIColor wrappers.
//
// Usage:
//   .foregroundStyle(AppColors.textPrimary)
//   .background(AppColors.raised)
//   AppColors.stateText(for: readinessState)

enum AppColors {

    // MARK: Brand

    /// Lime green — primary brand / CTA background / active state
    static let brandPrimary = Color(hex: "C8F135")
    /// Darker lime — secondary brand variant
    static let brandDark    = Color(hex: "9BBF1A")
    /// Muted brand tint — chip / badge backgrounds on dark surfaces
    static let brandMuted   = Color(hex: "3D4A1A")

    // MARK: Base surfaces

    /// Page / screen background
    static let bg      = Color(hex: "0D0F0B")
    /// Slightly raised surface (list rows, inner panels)
    static let surface = Color(hex: "1A1D16")
    /// Card / elevated surface
    static let raised  = Color(hex: "222619")
    /// Dividers, borders, ring tracks
    static let border  = Color(hex: "3A4030")

    // MARK: Text

    static let textPrimary   = Color(hex: "F0F5E8")
    static let textSecondary = Color(hex: "9AA88C")
    static let textMuted     = Color(hex: "5C6652")
    /// Use on brandPrimary backgrounds (CTA buttons)
    static let textOnBrand   = Color(hex: "0D0F0B")

    // MARK: Semantic

    /// Amber — calories, alerts, caution
    static let warning = Color(hex: "F5A623")
    /// Red — danger, rest state
    static let danger  = Color(hex: "E8453C")
    /// Blue — sleep, info
    static let info    = Color(hex: "4DA6FF")

    // MARK: Metric

    /// Active ring / progress fill (= brandPrimary)
    static let metricActive   = Color(hex: "C8F135")
    /// Inactive ring track
    static let metricInactive = Color(hex: "323D28")

    // MARK: - Backward-compatible aliases used throughout the codebase

    // These map old names to new tokens so callers outside AppColors
    // can be migrated file-by-file without breakage.

    static let accent      = brandPrimary
    static let accentSoft  = brandMuted
    static let background  = bg
    static let card        = raised
    static let shadowColor = Color.clear

    static let greenBase = metricActive
    static let greenSoft = brandMuted
    static let greenText = brandPrimary

    static let amberBase = warning
    static let amberSoft = warning.opacity(0.15)
    static let amberText = warning

    static let redBase = danger
    static let redSoft = danger.opacity(0.15)
    static let redText = danger

    static let dataProtein  = brandPrimary
    static let dataCarbs    = info
    static let dataFat      = danger
    static let dataCalories = warning
    static let dataSleep    = info

    // MARK: - State helpers

    /// Bright fill for ring / progress bar.
    static func stateBase(for state: ReadinessState) -> Color {
        switch state {
        case .green:  return brandPrimary
        case .yellow: return warning
        case .red:    return danger
        }
    }

    /// Muted tint for card / chip backgrounds.
    static func stateSoft(for state: ReadinessState) -> Color {
        switch state {
        case .green:  return brandMuted
        case .yellow: return warning.opacity(0.15)
        case .red:    return danger.opacity(0.15)
        }
    }

    /// Foreground colour for text / icons / filled buttons on dark surfaces.
    static func stateText(for state: ReadinessState) -> Color {
        switch state {
        case .green:  return brandPrimary
        case .yellow: return warning
        case .red:    return danger
        }
    }
}

// MARK: - Hex colour helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
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
