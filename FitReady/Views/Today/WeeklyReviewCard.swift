import SwiftUI

/// Weekly review card showing workouts completed, steps, calories and a simple
/// streak-free progress view for the current Mon–Sun week.
struct WeeklyReviewCard: View {

    @EnvironmentObject private var healthKit: HealthKitManager
    @AppStorage("weeklyPlan") private var weeklyPlan: String = "W,L,W,L,W,R,R"

    // MARK: - Derived

    /// Number of workouts logged this week.
    private var workoutsThisWeek: Int {
        let sessions = WorkoutStore.all()
        let cal = Calendar.current
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        return sessions.filter { $0.date >= weekStart }.count
    }

    /// Planned training days this week (from weeklyPlan).
    private var plannedWorkoutDays: Int {
        PlanDayType.week(from: weeklyPlan).filter { $0.isActive }.count
    }

    /// Total steps this week (sum of all 7 days in healthKit.weeklySteps).
    private var weeklyStepsTotal: Int {
        Int(healthKit.weeklySteps.values.reduce(0, +))
    }

    /// Total active kcal this week.
    private var weeklyKcalTotal: Int {
        Int(healthKit.weeklyActiveKcal.values.reduce(0, +))
    }

    /// Days with ≥ 10 000 steps.
    private var stepGoalDays: Int {
        healthKit.weeklySteps.values.filter { $0 >= 10_000 }.count
    }

    /// Current week's Mon–Sun day letters for the mini strip.
    private var weekDays: [(letter: String, isToday: Bool, hasSufficientSteps: Bool)] {
        let cal  = Calendar.current
        let now  = Date()
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
        let letters = ["M", "T", "W", "T", "F", "S", "S"]
        return (0..<7).map { offset in
            let day    = cal.date(byAdding: .day, value: offset, to: weekStart)!
            let isToday = cal.isDate(day, inSameDayAs: now)
            let steps  = healthKit.weeklySteps.first(where: { cal.isDate($0.key, inSameDayAs: day) })?.value ?? 0
            return (letter: letters[offset], isToday: isToday, hasSufficientSteps: steps >= 7_500)
        }
    }

    // MARK: - Body

    var body: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {

                // Section label
                HStack {
                    Text("THIS WEEK")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                        .kerning(0.5)
                    Spacer()
                    // Week date range
                    Text(weekRangeLabel)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(AppColors.textMuted)
                }

                // Day strip
                HStack(spacing: 0) {
                    ForEach(Array(weekDays.enumerated()), id: \.offset) { _, day in
                        VStack(spacing: 4) {
                            Text(day.letter)
                                .font(.system(size: 10, weight: day.isToday ? .bold : .regular))
                                .foregroundStyle(day.isToday ? AppColors.brandForeground : AppColors.textMuted)

                            Circle()
                                .fill(day.hasSufficientSteps ? AppColors.brandPrimary : AppColors.surface)
                                .frame(width: 7, height: 7)
                                .overlay(
                                    Circle().strokeBorder(
                                        day.hasSufficientSteps ? AppColors.brandPrimary : DS.Border.color,
                                        lineWidth: 1
                                    )
                                )
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                Divider()

                // Stats row
                HStack(spacing: 0) {
                    weekStat(
                        icon: "dumbbell.fill",
                        color: AppColors.brandForeground,
                        value: "\(workoutsThisWeek) / \(plannedWorkoutDays)",
                        label: "workouts"
                    )
                    Divider().frame(height: 36)
                    weekStat(
                        icon: "figure.walk",
                        color: AppColors.info,
                        value: stepsFormatted(weeklyStepsTotal),
                        label: "steps"
                    )
                    Divider().frame(height: 36)
                    weekStat(
                        icon: "flame.fill",
                        color: AppColors.dataCalories,
                        value: "\(weeklyKcalTotal)",
                        label: "active kcal"
                    )
                }
            }
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func weekStat(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(AppColors.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func stepsFormatted(_ n: Int) -> String {
        n >= 1000 ? String(format: "%.1fk", Double(n) / 1000) : "\(n)"
    }

    private var weekRangeLabel: String {
        let cal   = Calendar.current
        guard let interval = cal.dateInterval(of: .weekOfYear, for: Date()) else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        let endDay = cal.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        return "\(fmt.string(from: interval.start)) – \(fmt.string(from: endDay))"
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        DS.Background.page.ignoresSafeArea()
        WeeklyReviewCard()
            .padding(.horizontal, DS.Spacing.lg)
            .environmentObject(HealthKitManager())
    }
    .preferredColorScheme(.dark)
}
