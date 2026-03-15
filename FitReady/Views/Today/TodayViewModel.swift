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

    @Published var heroMessage: HeroMessage = HeroMessage(headline: "", supportingLine: "")

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
        // Mock hero message seeded from state
        let mockHeadline: String
        switch mockState {
        case .green:  mockHeadline = "Your body's ready. Make it count."
        case .yellow: mockHeadline = "Take it steady today."
        case .red:    mockHeadline = "Rest today. Let your body recover."
        }
        self.heroMessage = HeroMessage(headline: mockHeadline, supportingLine: data.readinessReason)
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

        self.heroMessage = makeHeroMessage(
            state:      state,
            status:     userStatus,
            nutrition:  nutrition,
            activity:   activity,
            hasWorkout: !healthKit.todayWorkouts.isEmpty,
            reason:     self.readinessReason
        )
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

    // swiftlint:disable:next function_body_length
    private func makeHeroMessage(
        state:      ReadinessState,
        status:     UserStatus,
        nutrition:  NutritionSummary,
        activity:   ActivitySummary,
        hasWorkout: Bool,
        reason:     String,
        now:        Date = Date()
    ) -> HeroMessage {

        let hour = Calendar.current.component(.hour, from: now)

        // Priority 1 — Status overrides
        switch status {
        case .sick:
            return HeroMessage(
                headline:       "Take it easy today.\nYour body is fighting.",
                supportingLine: "Skip training — rest is the best medicine."
            )
        case .injured:
            return HeroMessage(
                headline:       "Protect your recovery.\nModified movement only.",
                supportingLine: "Listen to your body. Gentle movement only."
            )
        case .onBreak:
            return HeroMessage(
                headline:       "Enjoy your break.\nYou've earned the rest.",
                supportingLine: "Consistency matters. Breaks are part of the plan."
            )
        case .active:
            break
        }

        // Helper ratios
        let proteinRatio = nutrition.proteinTarget > 0
            ? Double(nutrition.proteinConsumed) / Double(nutrition.proteinTarget) : 0
        let kcalRatio    = nutrition.kcalTarget > 0
            ? Double(nutrition.kcalConsumed)    / Double(nutrition.kcalTarget)    : 0

        // Priority 2 — Workout logged today
        if hasWorkout {
            let supporting: String
            if proteinRatio >= 0.9      { supporting = "Nutrition's on point." }
            else if proteinRatio < 0.6  { supporting = "Protein's a bit low — one more meal." }
            else                        { supporting = "Refuel within the hour." }
            return HeroMessage(headline: "Good session. Recovery starts now.", supportingLine: supporting)
        }

        // Priority 3 — Readiness × food combos
        switch state {
        case .red:
            if kcalRatio > 1.1 {
                return HeroMessage(headline: "Full rest today.",
                                   supportingLine: "Big day for food — your body's processing.")
            }
            if proteinRatio < 0.6 {
                return HeroMessage(headline: "Rest day. Eat well.",
                                   supportingLine: "Fuel your recovery — protein's low.")
            }
            if proteinRatio >= 0.9 {
                return HeroMessage(headline: "Full rest. You've earned it.",
                                   supportingLine: "Nutrition's on point — good day.")
            }
        case .yellow:
            if kcalRatio > 1.1 {
                return HeroMessage(headline: "Easy does it today.",
                                   supportingLine: "Your body's working hard after yesterday.")
            }
        case .green:
            if proteinRatio >= 0.9 && activity.steps >= 10_000 {
                return HeroMessage(headline: "Locked in today.",
                                   supportingLine: "Nutrition and movement both on track.")
            }
        }

        // Priority 4 — Time-aware headline
        let headline: String
        switch state {
        case .green:
            headline = hour < 11 ? "Your body's ready. Make it count."
                     : hour < 19 ? "Strong day so far."
                     :             "Finished strong."
        case .yellow:
            headline = hour < 11 ? "Take it steady today."
                     : hour < 19 ? "Keep it easy today."
                     :             "Good call taking it light."
        case .red:
            headline = hour < 11 ? "Rest day. Let your body recover."
                     : hour < 19 ? "Full rest today."
                     :             "Good rest day. Recovery done."
        }

        // Supporting line — first signal that applies
        let supporting: String
        if proteinRatio < 0.5 && hour >= 11 {
            supporting = "Protein's a bit low — one more meal will do it."
        } else if activity.steps < 3_000 && hour >= 15 {
            supporting = "A short walk would round out the day."
        } else if kcalRatio > 1.1 {
            supporting = "Big intake today — keep activity moderate."
        } else if activity.activeKcal < 150 && hour >= 15 && state == .green {
            supporting = "You haven't moved much — a walk counts."
        } else if kcalRatio >= 0.8 && kcalRatio <= 1.1 && proteinRatio >= 0.9 {
            supporting = "Nutrition's on point today."
        } else {
            supporting = reason
        }

        return HeroMessage(headline: headline, supportingLine: supporting)
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
