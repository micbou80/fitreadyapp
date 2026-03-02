import SwiftUI

enum ReadinessVerdict: Equatable {
    case ready, light, rest

    var label: String {
        switch self {
        case .ready: return "READY"
        case .light: return "GO LIGHT"
        case .rest:  return "REST DAY"
        }
    }

    var subtitle: String {
        switch self {
        case .ready: return "You're good to push hard today"
        case .light: return "Keep it easy, focus on movement"
        case .rest:  return "Your body needs to recover"
        }
    }

    var color: Color {
        switch self {
        case .ready: return Color(red: 0.20, green: 0.78, blue: 0.35)
        case .light: return Color(red: 1.00, green: 0.55, blue: 0.26)
        case .rest:  return Color(red: 0.88, green: 0.36, blue: 0.36)
        }
    }

    var icon: String {
        switch self {
        case .ready: return "bolt.fill"
        case .light: return "figure.walk"
        case .rest:  return "moon.zzz.fill"
        }
    }

    var ringProgress: Double {
        switch self {
        case .ready: return 0.85
        case .light: return 0.52
        case .rest:  return 0.18
        }
    }
}

struct ReadinessScore {
    let verdict: ReadinessVerdict
    let totalScore: Int
    let hrvScore: Int      // -1, 0, +1
    let rhrScore: Int
    let sleepScore: Int
    let todayHRV: Double?
    let todayRHR: Double?
    let todaySleep: Double?
    let baselineHRV: Double?
    let baselineRHR: Double?
}
