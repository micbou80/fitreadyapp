import SwiftUI

// MARK: - Design System namespace
// Colors delegate to AppColors — the single source of truth.

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

    // MARK: Shadow (zeroed — dark UI uses borders instead)
    enum Shadow {
        static let color:  Color   = .clear
        static let radius: CGFloat = 0
        static let y:      CGFloat = 0
    }

    // MARK: Border
    enum Border {
        static var color: Color { AppColors.border }
    }

    // MARK: Background (delegates to AppColors)
    enum Background {
        static var page:    Color { AppColors.bg }
        static var card:    Color { AppColors.raised }
        static var surface: Color { AppColors.surface }
    }

    // MARK: State colours (delegates to AppColors)
    enum StateColor {
        static func background(for state: ReadinessState) -> Color {
            AppColors.stateSoft(for: state)
        }

        /// Accessible foreground colour for each state (text / icon / button fill)
        static func primary(for state: ReadinessState) -> Color {
            AppColors.stateText(for: state)
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
