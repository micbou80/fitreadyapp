import SwiftUI
import Combine

@MainActor
final class TodayViewModel: ObservableObject {

    // MARK: - Published state

    @Published var readinessState:    ReadinessState
    @Published var readinessReason:   String
    @Published var recommendedAction: TodayAction
    @Published var secondaryActions:  [SecondaryAction]
    @Published var momentum:          MomentumSummary
    @Published var winMessage:        String?
    @Published var collapsedStats:    CollapsedStats

    @Published var todayPlanLabel: String = ""

    @Published var expandedMetricsVisible: Bool = false
    @Published var detailsSheetVisible:    Bool = false
    @Published var showingScanner:         Bool = false

    // Readiness details for the sheet
    @Published var todayHRV:    Double? = nil
    @Published var todayRHR:    Double? = nil
    @Published var todaySleep:  Double? = nil
    @Published var baselineHRV: Double? = nil
    @Published var baselineRHR: Double? = nil
    @Published var lastUpdated: Date?   = nil

    // MARK: - Init (mock)

    init(mockState: ReadinessState = .yellow) {
        let data = TodayMockData.make(state: mockState)
        self.readinessState    = data.readinessState
        self.readinessReason   = data.readinessReason
        self.recommendedAction = data.recommendedAction
        self.secondaryActions  = data.secondaryActions
        self.momentum          = data.momentum
        self.winMessage        = data.winMessage
        self.collapsedStats    = data.collapsedStats
    }

    // MARK: - HealthKit integration

    /// Derives all published state from a live ReadinessScore + HealthKitManager data.
    /// `mealTotals` provides scanned-meal fallback when HealthKit nutrition is unavailable.
    /// `planLetter` is today's letter from `weeklyPlan` ("W"/"L"/"R"); worst-case blending applied.
    /// `weeklySteps` powers the real momentum ring.
    func update(from score: ReadinessScore,
                healthKit: HealthKitManager,
                macroTargets: MacroTargets?,
                mealTotals: (kcal: Double?, protein: Double?, fat: Double?, carbs: Double?)? = nil,
                planLetter: String = "W",
                weeklySteps: [Date: Double] = [:]) {

        let state: ReadinessState
        switch score.verdict {
        case .ready: state = .green
        case .light: state = .yellow
        case .rest:  state = .red
        }

        let planLabelText: String
        switch planLetter {
        case "W": planLabelText = "Today's plan: Train day"
        case "L": planLabelText = "Today's plan: Light session"
        case "R": planLabelText = "Today's plan: Rest day"
        default:  planLabelText = ""
        }

        // Priority: HealthKit > scanned meals > 0
        let nutrition = NutritionSummary(
            kcalConsumed:    Int(healthKit.todayKcal     ?? mealTotals?.kcal    ?? 0),
            kcalTarget:      macroTargets?.kcal      ?? 2000,
            proteinConsumed: Int(healthKit.todayProteinG ?? mealTotals?.protein ?? 0),
            proteinTarget:   macroTargets?.proteinG  ?? 150,
            fatConsumed:     Int(healthKit.todayFatG     ?? mealTotals?.fat     ?? 0),
            fatTarget:       macroTargets?.fatG      ?? 65,
            carbsConsumed:   Int(healthKit.todayCarbsG   ?? mealTotals?.carbs   ?? 0),
            carbsTarget:     macroTargets?.carbsG    ?? 200
        )
        let activity = ActivitySummary(
            steps:      Int(healthKit.todaySteps     ?? 0),
            activeKcal: Int(healthKit.todayActiveKcal ?? 0),
            stepGoal:   10_000
        )

        self.readinessState    = state
        self.todayPlanLabel    = planLabelText
        self.readinessReason   = makeReason(score: score)
        self.recommendedAction = TodayMockData.makePlan(for: state)
        self.secondaryActions  = TodayMockData.makeSecondary(for: state)
        self.collapsedStats    = CollapsedStats(
            steps:            activity.steps,
            stepGoal:         activity.stepGoal,
            activeKcal:       activity.activeKcal,
            proteinRemaining: nutrition.proteinRemaining,
            nutrition:        nutrition,
            activity:         activity
        )
        self.momentum      = makeMomentum(weeklySteps: weeklySteps)
        self.todayHRV    = score.todayHRV
        self.todayRHR    = score.todayRHR
        self.todaySleep  = score.todaySleep
        self.baselineHRV = score.baselineHRV
        self.baselineRHR = score.baselineRHR
        self.lastUpdated = healthKit.lastLoadedAt
    }

    // MARK: - Actions

    func completeAction() {
        Haptics.notification(.success)
    }

    // MARK: - Private helpers

    private func makeReason(score: ReadinessScore) -> String {
        var parts: [String] = []
        if let hrv = score.todayHRV, let base = score.baselineHRV, base > 0 {
            let ratio = hrv / base
            if ratio >= 0.95    { parts.append("HRV strong") }
            else if ratio >= 0.80 { parts.append("HRV slightly low") }
            else                  { parts.append("HRV low") }
        }
        if let rhr = score.todayRHR, let base = score.baselineRHR, base > 0 {
            let ratio = rhr / base
            if ratio <= 1.03     { parts.append("heart rate steady") }
            else if ratio <= 1.08 { parts.append("heart rate slightly elevated") }
            else                   { parts.append("heart rate elevated") }
        }
        if let sleep = score.todaySleep {
            if sleep >= 7.5    { parts.append("sleep solid") }
            else if sleep >= 6 { parts.append("sleep a bit short") }
            else               { parts.append("sleep short") }
        }
        return parts.isEmpty ? "" : parts.joined(separator: " · ") + "."
    }

    /// Counts active days (steps > 5 000) in the current Mon–Sun week from HealthKit data.
    private func makeMomentum(weeklySteps: [Date: Double]) -> MomentumSummary {
        guard !weeklySteps.isEmpty else {
            return MomentumSummary(onTrackDays: 0, targetDays: 5, message: "Tracking your weekly momentum")
        }
        let threshold: Double = 5_000
        let onTrack = weeklySteps.values.filter { $0 >= threshold }.count
        let target  = 5
        let message: String
        switch onTrack {
        case 0:        message = "Get moving — every step counts"
        case 1:        message = "1 active day so far — keep building"
        case 2:        message = "2 active days — momentum is forming"
        case 3:        message = "Halfway there — great consistency"
        case 4:        message = "4 active days — almost a perfect week"
        default:       message = "\(onTrack) active days — outstanding week"
        }
        return MomentumSummary(onTrackDays: onTrack, targetDays: target, message: message)
    }
}
