import SwiftUI

// MARK: - AppColors — single source of truth for every color in the app.
//
// Usage:
//   .foregroundStyle(AppColors.greenText)
//   .background(AppColors.background)
//   AppColors.stateBase(for: readinessState)

enum AppColors {

    // MARK: Adaptive base (light / dark mode)

    /// Page / screen background  — #F7F8FA light / #0B1220 dark
    static let background = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.043, green: 0.071, blue: 0.125, alpha: 1)   // #0B1220
            : UIColor(red: 0.969, green: 0.973, blue: 0.980, alpha: 1)   // #F7F8FA
    })

    /// Card / surface background  — #FFFFFF light / #111827 dark
    static let card = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.067, green: 0.094, blue: 0.153, alpha: 1)   // #111827
            : .white
    })

    // MARK: Text & chrome

    static let textPrimary   = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
    static let divider       = Color(.separator)
    static let shadowColor   = Color.black.opacity(0.06)

    // MARK: Accent

    /// Brand purple — #7C3AED
    static let accent     = Color(hex: "7C3AED")
    /// Soft purple tint — #F3E8FF
    static let accentSoft = Color(hex: "F3E8FF")

    // MARK: State — green (ready / workout)

    /// Bright fill for rings, progress bars — #22C55E
    static let greenBase = Color(hex: "22C55E")
    /// Soft tint background — #E8F7EE
    static let greenSoft = Color(hex: "E8F7EE")
    /// Dark readable text / icon / button fill on white — #166534
    static let greenText = Color(hex: "166534")

    // MARK: State — amber (light / caution)

    /// Bright fill for rings, progress bars — #F59E0B
    static let amberBase = Color(hex: "F59E0B")
    /// Soft tint background — #FFF4E5
    static let amberSoft = Color(hex: "FFF4E5")
    /// Dark readable text / icon / button fill on white — #92400E
    static let amberText = Color(hex: "92400E")

    // MARK: State — red (rest / warning)

    /// Bright fill for rings, progress bars — #EF4444
    static let redBase = Color(hex: "EF4444")
    /// Soft tint background — #FDECEC
    static let redSoft = Color(hex: "FDECEC")
    /// Dark readable text / icon / button fill on white — #7F1D1D
    static let redText = Color(hex: "7F1D1D")

    // MARK: Nutrition / data chart colors

    /// Protein — #22C55E  (green)
    static let dataProtein   = Color(hex: "22C55E")
    /// Carbohydrates — #3B82F6  (blue)
    static let dataCarbs     = Color(hex: "3B82F6")
    /// Fat — #F59E0B  (amber)
    static let dataFat       = Color(hex: "F59E0B")
    /// Calories / energy — #8B5CF6  (violet)
    static let dataCalories  = Color(hex: "8B5CF6")

    // MARK: Misc data colors

    /// Sleep / HRV trend line — #6282FA  (periwinkle-blue)
    static let dataSleep     = Color(hex: "6282FA")

    // MARK: - State helpers

    /// Bright base color for ring fills, chart marks.
    static func stateBase(for state: ReadinessState) -> Color {
        switch state {
        case .green:  return greenBase
        case .yellow: return amberBase
        case .red:    return redBase
        }
    }

    /// Soft tint for card / chip backgrounds.
    static func stateSoft(for state: ReadinessState) -> Color {
        switch state {
        case .green:  return greenSoft
        case .yellow: return amberSoft
        case .red:    return redSoft
        }
    }

    /// Dark foreground color for text / icons / filled buttons on white surfaces.
    static func stateText(for state: ReadinessState) -> Color {
        switch state {
        case .green:  return greenText
        case .yellow: return amberText
        case .red:    return redText
        }
    }
}

// MARK: - Hex colour helper (moved here from DesignTokens.swift)

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
