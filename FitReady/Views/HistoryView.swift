import SwiftUI

struct InsightsView: View {

    @EnvironmentObject private var healthKit: HealthKitManager

    // Profile
    @AppStorage("heightCm")          private var heightCm: Double  = 0
    @AppStorage("ageYears")          private var ageYears: Int     = 0
    @AppStorage("biologicalSex")     private var biologicalSex: String = ""
    @AppStorage("activityLevel")     private var activityLevel: String = "moderate"
    @AppStorage("weightLossPace")    private var weightLossPace: Double = 0.5
    @AppStorage("primaryGoal")       private var primaryGoal: String = "lose"
    @AppStorage("proteinPerKg")      private var proteinPerKg: Double = 1.8
    @AppStorage("fatFloorPct")       private var fatFloorPct: Double = 25

    // Goal body composition
    @AppStorage("startWeightKg")     private var startWeight: Double = 0
    @AppStorage("goalWeightKg")      private var goalWeight: Double  = 0
    @AppStorage("manualWeightKg")    private var manualWeight: Double = 0
    @AppStorage("useManualWeight")   private var useManualWeight: Bool = false
    @AppStorage("startBodyFatPct")   private var startBodyFat: Double = 0
    @AppStorage("goalBodyFatPct")    private var goalBodyFat: Double = 0
    @AppStorage("manualBodyFatPct")  private var manualBodyFat: Double = 0
    @AppStorage("useManualBodyFat")  private var useManualBodyFat: Bool = false

    // Weekly consistency
    @AppStorage("sleepTargetHours")  private var sleepTarget: Double = 7.5
    @AppStorage("stepGoal")          private var stepGoal: Double    = 10_000
    @AppStorage("mealsJSON")         private var mealsJSON: String   = "[]"

    // MARK: - Computed

    private var displayWeight: Double? {
        if useManualWeight { return manualWeight > 0 ? manualWeight : nil }
        return healthKit.currentWeightKg
    }

    private var displayBodyFat: Double? {
        if useManualBodyFat { return manualBodyFat > 0 ? manualBodyFat : nil }
        return healthKit.currentBodyFatPct
    }

    private var macroTargets: MacroTargets? {
        guard let w = displayWeight, heightCm > 0, ageYears > 0, !biologicalSex.isEmpty else { return nil }
        return MacroEngine.compute(
            weightKg: w, heightCm: heightCm, ageYears: ageYears,
            isMale: biologicalSex == "male",
            activityLevel: activityLevel, paceKgPerWeek: weightLossPace,
            proteinPerKg: proteinPerKg, fatFloorPct: fatFloorPct
        )
    }

    private var bmrValue: Double? {
        guard let w = displayWeight, heightCm > 0, ageYears > 0, !biologicalSex.isEmpty else { return nil }
        return MacroEngine.bmr(weightKg: w, heightCm: heightCm, ageYears: ageYears, isMale: biologicalSex == "male")
    }

    private var allMeals: [MealEntry] {
        (try? JSONDecoder().decode([MealEntry].self, from: Data(mealsJSON.utf8))) ?? []
    }

    private var todayIntakeKcal: Double? {
        if let hk = healthKit.todayKcal { return hk }
        let key = isoDate(Date())
        let s = allMeals.filter { $0.date == key }.reduce(0) { $0 + $1.kcal }
        return s > 0 ? s : nil
    }

    /// Mon → Sun dates for the current calendar week
    private var currentWeekDates: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        comps.weekday = 2 // Monday
        let monday = cal.date(from: comps) ?? today
        return (0..<7).map { cal.date(byAdding: .day, value: $0, to: monday)! }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Background.page.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: DS.Spacing.lg) {
                        WeeklyProgressHeroCard()
                            .environmentObject(healthKit)
                        goalProgressCard
                        thisWeekCard
                        energyBalanceCard
                        Spacer(minLength: DS.Spacing.xl)
                    }
                    .padding(.top, DS.Spacing.lg)
                    .padding(.horizontal, DS.Spacing.lg)
                }
            }
            .navigationTitle("Insights")
        }
    }

    // MARK: - Section 1: Goal Progress

    private var goalProgressCard: some View {
        InsightCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                insightHeader(icon: "target", title: "Goal Progress")

                if goalWeight == 0 {
                    nudge(icon: "arrow.right.circle", text: "Set your goal weight in Goals to track progress")
                } else if let current = displayWeight {
                    // Show full start→current→goal bar if startWeight is known
                    if startWeight > 0 {
                        weightProgressRow(start: startWeight, current: current, goal: goalWeight)
                    } else {
                        weightSimpleRow(current: current, goal: goalWeight)
                    }
                    if let bf = displayBodyFat, goalBodyFat > 0 {
                        Divider().padding(.vertical, DS.Spacing.xs)
                        bodyFatRow(current: bf, goal: goalBodyFat)
                    }
                } else {
                    nudge(icon: "scalemass", text: "No weight data — add a reading in Goals")
                }
            }
        }
    }

    private func weightProgressRow(start: Double, current: Double, goal: Double) -> some View {
        let range     = abs(start - goal)
        let moved     = start > goal ? start - current : current - start
        let fraction  = range > 0 ? min(max(moved / range, 0), 1) : 0
        let remaining = abs(current - goal)
        let weeksLeft: Double? = abs(weightLossPace) > 0.01 ? remaining / abs(weightLossPace) : nil
        let isLoss    = goal < start

        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(AppColors.metricInactive).frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.accent)
                        .frame(width: geo.size.width * fraction, height: 8)
                        .animation(.spring(response: 0.5), value: fraction)
                }
            }
            .frame(height: 8)

            HStack {
                Text(String(format: "%.1f kg", start))
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.textMuted)
                Spacer()
                Text(String(format: "%.1f kg", current))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
                Text(String(format: "%.1f kg", goal))
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.textMuted)
            }

            if remaining < 0.2 {
                Text("Goal reached!")
                    .font(DS.Typography.body())
                    .foregroundStyle(AppColors.greenText)
            } else if let w = weeksLeft {
                let direction = isLoss ? "to lose" : "to gain"
                Text(String(format: "%.1f kg \(direction) · ~%.0f weeks at current pace", remaining, w))
                    .font(DS.Typography.body())
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                Text(String(format: "%.1f kg remaining", remaining))
                    .font(DS.Typography.body())
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    /// Simpler row when no start weight is recorded — shows current vs. goal only
    private func weightSimpleRow(current: Double, goal: Double) -> some View {
        let remaining = abs(current - goal)
        let isLoss    = goal < current
        let weeksLeft: Double? = abs(weightLossPace) > 0.01 ? remaining / abs(weightLossPace) : nil

        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                Text(String(format: "%.1f kg", current))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Image(systemName: isLoss ? "arrow.down" : "arrow.up")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
                Text(String(format: "%.1f kg goal", goal))
                    .font(DS.Typography.body())
                    .foregroundStyle(AppColors.textSecondary)
            }

            if remaining < 0.2 {
                Text("Goal reached!")
                    .font(DS.Typography.caption())
                    .foregroundStyle(AppColors.greenText)
            } else if let w = weeksLeft {
                let direction = isLoss ? "to lose" : "to gain"
                Text(String(format: "%.1f kg \(direction) · ~%.0f weeks at current pace", remaining, w))
                    .font(DS.Typography.caption())
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                Text(String(format: "%.1f kg remaining", remaining))
                    .font(DS.Typography.caption())
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private func bodyFatRow(current: Double, goal: Double) -> some View {
        let isLoss    = goal < current
        let remaining = abs(current - goal)

        if startBodyFat > 0 {
            // Full start → current → goal bar
            let range    = abs(startBodyFat - goal)
            let moved    = isLoss ? startBodyFat - current : current - startBodyFat
            let fraction = range > 0 ? min(max(moved / range, 0), 1) : 0

            return AnyView(
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("Body Fat")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4).fill(AppColors.metricInactive).frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppColors.accent)
                                .frame(width: geo.size.width * fraction, height: 8)
                                .animation(.spring(response: 0.5), value: fraction)
                        }
                    }
                    .frame(height: 8)
                    HStack {
                        Text(String(format: "%.1f%%", startBodyFat))
                            .font(.system(size: 13)).foregroundStyle(AppColors.textMuted)
                        Spacer()
                        Text(String(format: "%.1f%%", current))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        Spacer()
                        Text(String(format: "%.1f%%", goal))
                            .font(.system(size: 13)).foregroundStyle(AppColors.textMuted)
                    }
                    Text(String(format: "%.1f%% \(isLoss ? "to lose" : "to gain")", remaining))
                        .font(DS.Typography.body())
                        .foregroundStyle(AppColors.textSecondary)
                }
            )
        } else {
            // Simple current → goal without start reference
            return AnyView(
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("Body Fat")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                        Text(String(format: "%.1f%%", current))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Image(systemName: isLoss ? "arrow.down" : "arrow.up")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColors.accent)
                        Text(String(format: "%.1f%% goal", goal))
                            .font(DS.Typography.body())
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    Text(String(format: "%.1f%% \(isLoss ? "to lose" : "to gain")", remaining))
                        .font(DS.Typography.body())
                        .foregroundStyle(AppColors.textSecondary)
                }
            )
        }
    }

    // MARK: - Section 2: This Week

    private var thisWeekCard: some View {
        InsightCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                insightHeader(icon: "calendar", title: "This Week")
                VStack(spacing: DS.Spacing.sm) {
                    moveRow
                    Divider()
                    eatRow
                    Divider()
                    restRow
                }
            }
        }
    }

    private var moveRow: some View {
        let dots = currentWeekDates.map { date -> DotState in
            let today = Calendar.current.startOfDay(for: Date())
            if date > today { return .future }
            guard let s = weeklyStepsValue(for: date) else { return .empty }
            if s >= stepGoal { return .green }
            if s >= stepGoal * 0.5 { return .amber }
            return .gray
        }
        let values = currentWeekDates.compactMap { weeklyStepsValue(for: $0) }
        let avg = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        return pillRow(icon: "figure.walk", title: "Move",
                       dots: dots,
                       summary: avg.map { String(format: "%.0f steps/d", $0) } ?? "No data")
    }

    private var eatRow: some View {
        let target = macroTargets.map { Double($0.proteinG) }
                  ?? displayWeight.map { $0 * proteinPerKg }
                  ?? 0
        let dots = currentWeekDates.map { date -> DotState in
            let today = Calendar.current.startOfDay(for: Date())
            if date > today { return .future }
            guard let p = dailyProtein(for: date), target > 0 else { return .empty }
            if p >= target * 0.9 { return .green }
            if p >= target * 0.6 { return .amber }
            return .gray
        }
        let values = currentWeekDates.compactMap { dailyProtein(for: $0) }
        let avg = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        return pillRow(icon: "fork.knife", title: "Eat",
                       dots: dots,
                       summary: avg.map { String(format: "%.0f g protein/d", $0) } ?? "No data")
    }

    private var restRow: some View {
        let dots = currentWeekDates.map { date -> DotState in
            let today = Calendar.current.startOfDay(for: Date())
            if date > today { return .future }
            guard let h = dailySleep(for: date) else { return .empty }
            if h >= sleepTarget { return .green }
            if h >= 6.0 { return .amber }
            return .gray
        }
        let values = currentWeekDates.compactMap { dailySleep(for: $0) }
        let avg = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        return pillRow(icon: "moon.fill", title: "Rest",
                       dots: dots,
                       summary: avg.map { String(format: "%.1f h sleep/d", $0) } ?? "No data")
    }

    private func pillRow(icon: String, title: String, dots: [DotState], summary: String) -> some View {
        HStack(spacing: 0) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.accent)
                .frame(width: 16)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 36, alignment: .leading)
                .padding(.leading, DS.Spacing.sm)

            // Explicit gap between label and dots
            Spacer().frame(width: DS.Spacing.md)

            HStack(spacing: 8) {
                ForEach(Array(dots.enumerated()), id: \.offset) { _, state in
                    dotView(state)
                }
            }

            Spacer(minLength: DS.Spacing.sm)

            Text(summary)
                .font(.system(size: 11))
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private enum DotState { case green, amber, gray, empty, future }

    @ViewBuilder
    private func dotView(_ state: DotState) -> some View {
        switch state {
        case .green:
            Circle().fill(AppColors.greenBase).frame(width: 11, height: 11)
        case .amber:
            Circle().fill(AppColors.amberBase).frame(width: 11, height: 11)
        case .gray:
            Circle().fill(AppColors.border).frame(width: 11, height: 11)
        case .empty:
            Circle()
                .strokeBorder(AppColors.metricInactive, lineWidth: 1.5)
                .frame(width: 11, height: 11)
        case .future:
            Text("–")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppColors.border)
                .frame(width: 11, alignment: .center)
        }
    }

    // MARK: - Section 3: Energy Balance

    private var energyBalanceCard: some View {
        InsightCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                insightHeader(icon: "bolt.fill", title: "Energy Balance")

                if let bmr = bmrValue, let targets = macroTargets {
                    let neat      = healthKit.todayActiveKcal ?? 0
                    let totalBurn = Double(targets.tdee)
                    // Goal deficit derived purely from pace: −550 kcal/day for 0.5 kg/week
                    let goalDef: Double? = abs(weightLossPace) > 0.001
                        ? -(weightLossPace * 7700.0 / 7.0)
                        : (macroTargets != nil ? 0.0 : nil)

                    VStack(spacing: 0) {
                        energyRow("Base (BMR)", value: bmr, bold: false)
                        energyRow("Active (NEAT)", value: neat, bold: false, prefix: "+ ")
                        Divider().padding(.vertical, DS.Spacing.xs)
                        energyRow("Total burn (TDEE)", value: totalBurn, bold: true)

                        if let intake = todayIntakeKcal {
                            Divider().padding(.vertical, DS.Spacing.xs)
                            energyRow("Food logged", value: intake, bold: false)
                            Divider().padding(.vertical, DS.Spacing.xs)
                            balanceRow(balance: intake - totalBurn, goalDef: goalDef)
                            if let gd = goalDef {
                                Text(String(format: "Goal: %+.0f kcal/day", gd))
                                    .font(DS.Typography.caption())
                                    .foregroundStyle(AppColors.textMuted)
                                    .padding(.top, DS.Spacing.xs)
                            }
                        } else {
                            Divider().padding(.vertical, DS.Spacing.xs)
                            nudge(icon: "fork.knife", text: "Log a meal today to see your balance")
                        }
                    }
                } else {
                    nudge(icon: "person.crop.circle.badge.exclamationmark",
                          text: "Complete your profile to see energy data")
                }
            }
        }
    }

    private func energyRow(_ label: String, value: Double, bold: Bool, prefix: String = "") -> some View {
        HStack {
            Text(label)
                .font(bold ? .system(size: 14, weight: .semibold) : DS.Typography.caption())
                .foregroundStyle(bold ? AppColors.textPrimary : AppColors.textSecondary)
            Spacer()
            Text("\(prefix)\(Int(value.rounded())) kcal")
                .font(bold ? .system(size: 14, weight: .semibold) : DS.Typography.caption())
                .foregroundStyle(bold ? AppColors.textPrimary : AppColors.textSecondary)
        }
        .padding(.vertical, 2)
    }

    private func balanceRow(balance: Double, goalDef: Double?) -> some View {
        let (chipText, chipColor) = balanceChip(balance: balance, goalDef: goalDef)
        return HStack {
            Text("Balance")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            HStack(spacing: DS.Spacing.sm) {
                Text(String(format: "%+.0f kcal", balance))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(chipColor)
                Text(chipText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(chipColor)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 3)
                    .background(chipColor.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 2)
    }

    private func balanceChip(balance: Double, goalDef: Double?) -> (String, Color) {
        if let gd = goalDef, gd < -50 {
            // Loss goal — deficit expected
            if balance > 0 { return ("Over target", AppColors.redText) }
            let onTarget = balance <= gd * 1.15 && balance >= gd * 0.85
            return onTarget ? ("On target", AppColors.greenText) : ("Under target", AppColors.amberText)
        } else if let gd = goalDef, gd > 50 {
            // Gain goal — surplus expected
            if balance < 0 { return ("Under target", AppColors.amberText) }
            let onTarget = balance >= gd * 0.85 && balance <= gd * 1.15
            return onTarget ? ("On target", AppColors.greenText) : ("Over target", AppColors.amberText)
        } else {
            // Maintenance
            if abs(balance) <= 150 { return ("Balanced", AppColors.greenText) }
            return balance > 0 ? ("Surplus", AppColors.amberText) : ("Deficit", AppColors.amberText)
        }
    }

    // MARK: - Data helpers

    private func isoDate(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    private func weeklyStepsValue(for date: Date) -> Double? {
        let today = Calendar.current.startOfDay(for: Date())
        if date == today { return healthKit.todaySteps }
        return healthKit.weeklySteps[date]
    }

    private func dailyProtein(for date: Date) -> Double? {
        let today = Calendar.current.startOfDay(for: Date())
        if date == today, let hk = healthKit.todayProteinG { return hk }
        let key = isoDate(date)
        let meals = allMeals.filter { $0.date == key }
        if meals.isEmpty { return nil }
        return meals.reduce(0) { $0 + $1.proteinG }
    }

    private func dailySleep(for date: Date) -> Double? {
        let cal = Calendar.current
        if let m = healthKit.todayMetrics, cal.isDate(m.date, inSameDayAs: date) {
            return m.sleepHours
        }
        return healthKit.baselineMetrics.first { cal.isDate($0.date, inSameDayAs: date) }?.sleepHours
    }

    // MARK: - Shared UI helpers

    private func insightHeader(icon: String, title: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.accent)
            Text(title.uppercased())
                .font(DS.Typography.label())
                .foregroundStyle(AppColors.textSecondary)
                .kerning(0.5)
        }
    }

    private func nudge(icon: String, text: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.textMuted)
            Text(text)
                .font(DS.Typography.caption())
                .foregroundStyle(AppColors.textSecondary)
        }
    }
}

// MARK: - Card container

private struct InsightCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
        .shadow(color: DS.Shadow.color, radius: DS.Shadow.radius, x: 0, y: DS.Shadow.y)
    }
}

// MARK: - Weekly progress hero card

struct WeeklyProgressHeroCard: View {

    @EnvironmentObject private var healthKit: HealthKitManager
    @AppStorage("weeklyPlan") private var weeklyPlan: String = "W,L,W,L,W,R,R"

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Hero color helpers (mirrors TodayHeroSection light-mode treatment)

    /// In light mode the hero card always renders on a dark forest-green surface —
    /// so text must be forced light regardless of the system color scheme.
    private var heroTextColor: Color {
        colorScheme == .light ? Color(hex: "F2F2F2") : AppColors.textPrimary
    }
    private var heroSubtextColor: Color {
        colorScheme == .light ? Color(hex: "F2F2F2").opacity(0.75) : AppColors.textSecondary
    }
    private var heroMutedColor: Color {
        colorScheme == .light ? Color(hex: "F2F2F2").opacity(0.55) : AppColors.textMuted
    }
    /// Opaque deep-green overlay only in light mode (dark mode: .clear lets the material show through)
    private var heroBg: Color {
        colorScheme == .light ? Color(hex: "20422E") : .clear
    }

    // MARK: Derived — workouts

    private var workoutsThisWeek: Int {
        let sessions = WorkoutStore.all()
        let cal = Calendar.current
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        return sessions.filter { $0.date >= weekStart }.count
    }

    private var plannedWorkoutDays: Int {
        PlanDayType.week(from: weeklyPlan).filter { $0.isActive }.count
    }

    // MARK: Derived — totals

    private var weeklyStepsTotal: Int {
        let base = Int(healthKit.weeklySteps.values.reduce(0, +))
        if let today = healthKit.todaySteps {
            // weeklySteps may already include today depending on HK query — use max to avoid doubling
            let cal = Calendar.current
            let todayKey = healthKit.weeklySteps.keys.first { cal.isDateInToday($0) }
            if todayKey == nil { return base + Int(today) }
        }
        return base
    }

    private var weeklyKcalTotal: Int {
        let base = Int(healthKit.weeklyActiveKcal.values.reduce(0, +))
        if let today = healthKit.todayActiveKcal {
            let cal = Calendar.current
            let todayKey = healthKit.weeklyActiveKcal.keys.first { cal.isDateInToday($0) }
            if todayKey == nil { return base + Int(today) }
        }
        return base
    }

    // MARK: Derived — day strip (Mon–Sun)

    private struct DayInfo {
        let letter: String
        let isToday: Bool
        let hasWorkout: Bool
    }

    private var dayInfos: [DayInfo] {
        let cal = Calendar.current
        let now = Date()
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
        let sessions = WorkoutStore.all()
        let letters  = ["M", "T", "W", "T", "F", "S", "S"]
        return (0..<7).map { offset in
            let day     = cal.date(byAdding: .day, value: offset, to: weekStart)!
            let isToday = cal.isDate(day, inSameDayAs: now)
            // A workout day = any logged session on that calendar day
            let hasWorkout = sessions.contains { cal.isDate($0.date, inSameDayAs: day) }
            return DayInfo(letter: letters[offset], isToday: isToday, hasWorkout: hasWorkout)
        }
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {

            // Week label chip — mirrors TodayHeroSection readiness chip style
            Text("THIS WEEK")
                .font(DS.Typography.label())
                .foregroundStyle(AppColors.brandPrimary)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, 3)
                .background(AppColors.brandPrimary.opacity(0.12))
                .clipShape(Capsule())

            // Stat blocks
            HStack(spacing: 0) {
                statBlock(
                    value: "\(workoutsThisWeek) / \(plannedWorkoutDays)",
                    label: "Workouts"
                )
                Divider().frame(height: 36).opacity(0.3)
                statBlock(
                    value: "\(weeklyKcalTotal)",
                    label: "Active kcal"
                )
                Divider().frame(height: 36).opacity(0.3)
                statBlock(
                    value: stepsFormatted(weeklyStepsTotal),
                    label: "Steps"
                )
            }

            // 7-day dot strip
            HStack(spacing: 0) {
                ForEach(Array(dayInfos.enumerated()), id: \.offset) { _, day in
                    dayDot(day)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        // Three-layer background — matches TodayHeroSection exactly:
        //   1. heroBg: opaque dark green in light mode, clear in dark
        //   2. brandPrimary @ 8% glass tint (GlassTintGreen — Liquid Glass spec)
        //   3. ultraThinMaterial for frosted depth
        .background(heroBg)
        .background(AppColors.brandPrimary.opacity(0.08))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Corner.card)
                .strokeBorder(AppColors.brandPrimary.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: DS.Shadow.color, radius: DS.Shadow.radius, y: DS.Shadow.y)
    }

    // MARK: Sub-views

    @ViewBuilder
    private func statBlock(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(DS.Typography.hero())
                .foregroundStyle(heroTextColor)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(DS.Typography.label())
                .foregroundStyle(heroSubtextColor)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func dayDot(_ day: DayInfo) -> some View {
        VStack(spacing: 4) {
            Text(day.letter)
                .font(.system(size: 10, weight: day.isToday ? .bold : .regular))
                .foregroundStyle(day.isToday ? AppColors.brandPrimary : heroMutedColor)

            ZStack {
                if day.isToday {
                    // Today: filled brandPrimary dot with a subtle ring
                    Circle()
                        .strokeBorder(AppColors.brandPrimary.opacity(0.35), lineWidth: 2)
                        .frame(width: 14, height: 14)
                    Circle()
                        .fill(AppColors.brandPrimary)
                        .frame(width: 9, height: 9)
                } else if day.hasWorkout {
                    // Workout day: filled
                    Circle()
                        .fill(AppColors.brandPrimary)
                        .frame(width: 10, height: 10)
                } else {
                    // Rest / future: empty
                    Circle()
                        .strokeBorder(heroMutedColor.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 10, height: 10)
                }
            }
            .frame(width: 14, height: 14)
        }
    }

    // MARK: Helpers

    private func stepsFormatted(_ n: Int) -> String {
        n >= 1_000 ? String(format: "%.1fk", Double(n) / 1_000) : "\(n)"
    }
}
