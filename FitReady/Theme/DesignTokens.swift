import SwiftUI

// MARK: - Design System namespace

enum DS {

    // MARK: Spacing
    enum Spacing {
        static let xs: CGFloat  =  4
        static let sm: CGFloat  =  8
        static let md: CGFloat  = 12
        static let lg: CGFloat  = 16
        static let xl: CGFloat  = 24
    }

    // MARK: Corner radius
    enum Corner {
        static let card:   CGFloat = 20
        static let chip:   CGFloat = 10
        static let button: CGFloat = 14
    }

    // MARK: Shadow
    enum Shadow {
        static let color  = Color.black.opacity(0.06)
        static let radius: CGFloat = 12
        static let y:      CGFloat =  6
    }

    // MARK: Background
    enum Background {
        static let page = Color(hex: "F7F8FA")
        static let card = Color(.systemBackground)
    }

    // MARK: State colours
    enum StateColor {
        static let greenTint  = Color(hex: "E8F5EC")
        static let yellowTint = Color(hex: "FFF4E5")
        static let redTint    = Color(hex: "FDECEC")

        static func background(for state: ReadinessState) -> Color {
            switch state {
            case .green:  return greenTint
            case .yellow: return yellowTint
            case .red:    return redTint
            }
        }

        /// Accessible foreground colour for each state
        static func primary(for state: ReadinessState) -> Color {
            switch state {
            case .green:  return Color(hex: "1B7D38")   // deep green
            case .yellow: return Color(hex: "B45309")   // amber
            case .red:    return Color(hex: "C0392B")   // deep red
            }
        }
    }

    // MARK: Typography
    enum Typography {
        static func hero()    -> Font { .system(size: 30, weight: .bold,     design: .rounded) }
        static func title()   -> Font { .system(size: 18, weight: .semibold, design: .rounded) }
        static func body()    -> Font { .system(size: 15, weight: .regular) }
        static func caption() -> Font { .system(size: 13, weight: .regular) }
        static func label()   -> Font { .system(size: 11, weight: .semibold) }
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
