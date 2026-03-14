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
    @Published var todayPlanType: PlanDayType = .strength

    @Published var tdee: Int = 0

    @Published var expandedMetricsVisible: Bool = false
    @Published var detailsSheetVisible:    Bool = false
    @Published var showingScanner:         Bool = false

    // Readiness details for the sheet
    @Published var todayHRV:    Double? = nil
    @Published var todayRHR:    Double? = nil
    @Published var todaySleep:  Double? = nil
    @Published var baselineHRV: Double? = nil
    @Published var baselineRHR: Double? = nil
    @Published var hrvZ:        Double? = nil
    @Published var rhrDelta:    Double? = nil
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
    /// `planType` is today's planned activity type from `weeklyPlan`.
    /// `weeklySteps` powers the real momentum ring.
    /// Also published so TodayHeroSection can adapt copy to the user's self-reported status.
    @Published var currentUserStatus: UserStatus = .active

    func update(from score: ReadinessScore,
                healthKit: HealthKitManager,
                macroTargets: MacroTargets?,
                mealTotals: (kcal: Double?, protein: Double?, fat: Double?, carbs: Double?)? = nil,
                planType: PlanDayType = .strength,
                weeklySteps: [Date: Double] = [:],
                userStatus: UserStatus = .active) {

        currentUserStatus = userStatus

        // Derive base state from biometrics, then apply user status override
        let baseState: ReadinessState
        switch score.verdict {
        case .ready: baseState = .green
        case .light: baseState = .yellow
        case .rest:  baseState = .red
        }
        let state = userStatus.readinessOverride ?? baseState

        let planLabelText = "Today's plan: \(planType.label)"

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
        self.todayPlanType     = planType
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


        self.tdee          = macroTargets?.tdee ?? 0
        self.momentum      = makeMomentum(weeklySteps: weeklySteps)
        self.todayHRV    = score.todayHRV
        self.todayRHR    = score.todayRHR
        self.todaySleep  = score.todaySleep
        self.baselineHRV = score.baselineHRV
        self.baselineRHR = score.baselineRHR
        self.hrvZ        = score.hrvZ
        self.rhrDelta    = score.rhrDelta
        self.lastUpdated = healthKit.lastLoadedAt
    }

    // MARK: - Actions

    func completeAction() {
        Haptics.notification(.success)
    }

    // MARK: - Private helpers

    private func makeReason(score: ReadinessScore) -> String {
        var parts: [String] = []
        if let z = score.hrvZ {
            if z > 0.5        { parts.append("HRV above your norm") }
            else if z > -0.5  { parts.append("HRV within your norm") }
            else if z > -1.5  { parts.append("HRV slightly low") }
            else              { parts.append("HRV well below norm") }
        }
        if let delta = score.rhrDelta {
            if delta < 0      { parts.append("RHR below baseline") }
            else if delta < 3 { parts.append("RHR normal") }
            else if delta < 5 { parts.append("RHR slightly elevated") }
            else              { parts.append("RHR elevated") }
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
