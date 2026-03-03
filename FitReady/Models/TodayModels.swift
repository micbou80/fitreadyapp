import Foundation

// MARK: - Readiness state

enum ReadinessState {
    case green, yellow, red

    /// Short accessibility label (text, not just colour)
    var accessibilityLabel: String {
        switch self {
        case .green:  return "Train"
        case .yellow: return "Go lighter"
        case .red:    return "Recover"
        }
    }
}

// MARK: - Today action (primary CTA)

struct TodayAction {
    let title:            String   // "Go lighter today"
    let duration:         String   // "30–40 min"
    let ctaLabel:         String   // "Start Light Session"
    let bullets:          [String] // focus cues
    let completedMessage: String   // "Done. That counts."
    let nextSuggestion:   String   // shown after completion
}

// MARK: - Secondary actions

struct SecondaryAction: Identifiable {
    enum Kind { case scanMeal, quickRecovery, general }
    let icon:  String
    let label: String
    let kind:  Kind
    var id: String { label }
}

// MARK: - Momentum

struct MomentumSummary {
    let onTrackDays: Int
    let targetDays:  Int
    let message:     String
}

// MARK: - Nutrition summary

struct NutritionSummary {
    let kcalConsumed:    Int
    let kcalTarget:      Int
    let proteinConsumed: Int
    let proteinTarget:   Int
    let fatConsumed:     Int
    let fatTarget:       Int
    let carbsConsumed:   Int
    let carbsTarget:     Int

    var proteinRemaining: Int { max(0, proteinTarget - proteinConsumed) }
    var kcalRemaining:    Int { max(0, kcalTarget    - kcalConsumed) }
}

// MARK: - Activity summary

struct ActivitySummary {
    let steps:      Int
    let activeKcal: Int
    let stepGoal:   Int

    var stepProgress: Double { min(1.0, Double(steps) / Double(max(1, stepGoal))) }
}

// MARK: - Collapsed status (chip row)

struct CollapsedStats {
    let steps:            Int
    let stepGoal:         Int
    let activeKcal:       Int
    let proteinRemaining: Int
    let nutrition:        NutritionSummary
    let activity:         ActivitySummary
}

// MARK: - Mock data provider

enum TodayMockData {

    struct Bundle {
        let readinessState:    ReadinessState
        let readinessReason:   String
        let recommendedAction: TodayAction
        let secondaryActions:  [SecondaryAction]
        let momentum:          MomentumSummary
        let winMessage:        String?
        let collapsedStats:    CollapsedStats
    }

    static func make(state: ReadinessState) -> Bundle {
        let nutrition = NutritionSummary(
            kcalConsumed: 1240, kcalTarget: 2000,
            proteinConsumed: 68, proteinTarget: 145,
            fatConsumed: 42, fatTarget: 67,
            carbsConsumed: 110, carbsTarget: 212
        )
        let activity = ActivitySummary(steps: 5820, activeKcal: 312, stepGoal: 10_000)
        let stats = CollapsedStats(
            steps:            activity.steps,
            stepGoal:         activity.stepGoal,
            activeKcal:       activity.activeKcal,
            proteinRemaining: nutrition.proteinRemaining,
            nutrition:        nutrition,
            activity:         activity
        )
        return Bundle(
            readinessState:    state,
            readinessReason:   makeReason(for: state),
            recommendedAction: makePlan(for: state),
            secondaryActions:  makeSecondary(for: state),
            momentum:          MomentumSummary(onTrackDays: 3, targetDays: 5,
                                               message: "3 of 5 days on track this week"),
            winMessage: "Last win: +1 rep on Chest Press",
            collapsedStats: stats
        )
    }

    static func makePlan(for state: ReadinessState) -> TodayAction {
        switch state {
        case .green:
            return TodayAction(
                title:            "Train as planned",
                duration:         "45 min",
                ctaLabel:         "Start Workout",
                bullets:          ["Push your working sets", "Take full rest between sets"],
                completedMessage: "Done. That counts.",
                nextSuggestion:   "Great session. Log your meals and rest up tonight."
            )
        case .yellow:
            return TodayAction(
                title:            "Go lighter today",
                duration:         "30–40 min",
                ctaLabel:         "Start Light Session",
                bullets:          ["Keep intensity at 70–75%", "Focus on form over load"],
                completedMessage: "Done. That counts.",
                nextSuggestion:   "Good call. Light days protect your progress."
            )
        case .red:
            return TodayAction(
                title:            "Recovery day",
                duration:         "20 min",
                ctaLabel:         "Start Recovery Walk",
                bullets:          ["Easy pace, no breathlessness", "Gentle movement keeps momentum"],
                completedMessage: "Done. That counts.",
                nextSuggestion:   "Rest is training. You'll come back stronger tomorrow."
            )
        }
    }

    static func makeSecondary(for state: ReadinessState) -> [SecondaryAction] {
        let scanMeal = SecondaryAction(icon: "camera.viewfinder", label: "Scan meal", kind: .scanMeal)
        switch state {
        case .green:
            return [scanMeal, SecondaryAction(icon: "figure.walk", label: "Steps top-up\n10 min", kind: .general)]
        case .yellow, .red:
            return [scanMeal, SecondaryAction(icon: "figure.flexibility", label: "Quick Recovery\n7 min", kind: .quickRecovery)]
        }
    }

    static func makeReason(for state: ReadinessState) -> String {
        switch state {
        case .green:  return "HRV strong · heart rate steady."
        case .yellow: return "HRV slightly low · sleep a bit short."
        case .red:    return "HRV low · resting heart rate elevated."
        }
    }
}
