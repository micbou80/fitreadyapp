import UIKit

/// Thin wrapper around UIKit feedback generators.
enum Haptics {

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let g = UIImpactFeedbackGenerator(style: style)
        g.prepare()
        g.impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType = .success) {
        let g = UINotificationFeedbackGenerator()
        g.prepare()
        g.notificationOccurred(type)
    }
}
