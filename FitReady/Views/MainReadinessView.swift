import SwiftUI

enum ScheduledActivity: String, CaseIterable, Identifiable {
    case rest    = "rest"
    case run     = "run"
    case workout = "workout"

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .rest:    return "moon.zzz.fill"
        case .run:     return "figure.run"
        case .workout: return "dumbbell.fill"
        }
    }
}

struct MainReadinessView: View {

    @EnvironmentObject private var healthKit: HealthKitManager

    @AppStorage("baselineDays")          private var baselineDays: Int = 7
    @AppStorage("sleepTargetHours")      private var sleepTargetHours: Double = 7.5
    @AppStorage("hrvGoodThreshold")      private var hrvGoodThreshold: Double = 0.95
    @AppStorage("hrvNeutralThreshold")   private var hrvNeutralThreshold: Double = 0.80
    @AppStorage("rhrGoodThreshold")      private var rhrGoodThreshold: Double = 1.03
    @AppStorage("rhrNeutralThreshold")   private var rhrNeutralThreshold: Double = 1.08
    @AppStorage("goalWeightKg")          private var goalWeight: Double = 0
    @AppStorage("manualWeightKg")        private var manualWeight: Double = 0
    @AppStorage("useManualWeight")       private var useManualWeight: Bool = false
    @AppStorage("weeklyScheduleJSON")    private var weeklyScheduleJSON: String = "{}"
    // Macro settings
    @AppStorage("heightCm")             private var heightCm: Double = 0
    @AppStorage("ageYears")             private var ageYears: Int = 0
    @AppStorage("biologicalSex")        private var biologicalSex: String = ""
    @AppStorage("activityLevel")        private var activityLevel: String = "moderate"
    @AppStorage("weightLossPace")       private var weightLossPace: Double = 0.5
    @AppStorage("proteinPerKg")         private var proteinPerKg: Double = 1.8
    @AppStorage("fatFloorPct")          private var fatFloorPct: Double = 25
    // Meal log for macro actuals
    @AppStorage("mealsJSON")            private var mealsJSON: String = "[]"

    // MARK: - Computed

    private var settings: AppSettings {
        AppSettings(
            baselineDays: baselineDays,
            sleepTargetHours: sleepTargetHours,
            hrvGoodThreshold: hrvGoodThreshold,
            hrvNeutralThreshold: hrvNeutralThreshold,
            rhrGoodThreshold: rhrGoodThreshold,
            rhrNeutralThreshold: rhrNeutralThreshold
        )
    }

    private var displayWeight: Double? {
        if useManualWeight { return manualWeight > 0 ? manualWeight : nil }
        return healthKit.currentWeightKg
    }

    private var macroTargets: MacroTargets? {
        guard let wt = displayWeight,
              heightCm > 0, ageYears > 0, !biologicalSex.isEmpty else { return nil }
        return MacroEngine.compute(
            weightKg: wt,
            heightCm: heightCm,
            ageYears: ageYears,
            isMale: biologicalSex == "male",
            activityLevel: activityLevel,
            paceKgPerWeek: weightLossPace,
            proteinPerKg: proteinPerKg,
            fatFloorPct: fatFloorPct
        )
    }

    private var readinessScore: ReadinessScore? {
        guard let today = healthKit.todayMetrics,
              !healthKit.baselineMetrics.isEmpty else { return nil }
        return ReadinessEngine.compute(today: today, baseline: healthKit.baselineMetrics, settings: settings)
    }

    private var weeklySchedule: [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: Data(weeklyScheduleJSON.utf8))) ?? [:]
    }

    private var currentWeekDays: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: today)!
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
    }

    private var dateLabel: String {
        Date().formatted(.dateTime.weekday(.wide).month().day())
    }

    private var todayKey: String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    /// Macro actuals: HealthKit takes priority, then scanned meals
    private var actualKcal: Double? {
        healthKit.todayKcal ?? mealTotal(\.kcal)
    }
    private var actualProteinG: Double? {
        healthKit.todayProteinG ?? mealTotal(\.proteinG)
    }
    private var actualFatG: Double? {
        healthKit.todayFatG ?? mealTotal(\.fatG)
    }
    private var actualCarbsG: Double? {
        healthKit.todayCarbsG ?? mealTotal(\.carbsG)
    }

    private func mealTotal(_ keyPath: KeyPath<MealEntry, Double>) -> Double? {
        let meals = ((try? JSONDecoder().decode([MealEntry].self, from: Data(mealsJSON.utf8))) ?? [])
            .filter { $0.date == todayKey }
        guard !meals.isEmpty else { return nil }
        let total = meals.reduce(0.0) { $0 + $1[keyPath: keyPath] }
        return total > 0 ? total : nil
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if let error = healthKit.authError {
                    errorView(message: error)
                } else if healthKit.isLoading && healthKit.todayMetrics == nil {
                    loadingView
                } else if let score = readinessScore {
                    mainContent(score: score)
                } else {
                    noDataView
                }
            }
            .navigationTitle(dateLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if healthKit.isLoading {
                    ToolbarItem(placement: .topBarTrailing) {
                        ProgressView().scaleEffect(0.8)
                    }
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            ) { _ in
                Task { await healthKit.loadData(baselineDays: baselineDays) }
            }
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private func mainContent(score: ReadinessScore) -> some View {
        ScrollView {
            VStack(spacing: 24) {

                // Verdict + ring
                VStack(spacing: 6) {
                    Text(score.verdict.label)
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(score.verdict.color)

                    Text(score.verdict.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                        .multilineTextAlignment(.center)

                    let reason = reasonText(for: score)
                    if !reason.isEmpty {
                        Text(reason)
                            .font(.footnote)
                            .foregroundStyle(Color(.tertiaryLabel))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.top, 2)
                    }

                    if let t = healthKit.lastLoadedAt {
                        Text("Updated \(t.formatted(.dateTime.hour().minute()))")
                            .font(.caption2)
                            .foregroundStyle(Color(.tertiaryLabel))
                            .padding(.top, 4)
                    }
                }
                .padding(.top, 8)

                ReadinessRingView(score: score)

                // Weekly schedule
                weeklySchedulePicker

                // Activity snapshot: Steps + Active Kcal
                activityRow

                // Macro summary card
                if let targets = macroTargets {
                    MacroSummaryCard(
                        targets: targets,
                        actualKcal: actualKcal,
                        actualProteinG: actualProteinG,
                        actualFatG: actualFatG,
                        actualCarbsG: actualCarbsG
                    )
                    .padding(.horizontal, 16)
                }

                Spacer(minLength: 16)
            }
        }
    }

    // MARK: - Activity row

    @ViewBuilder
    private var activityRow: some View {
        HStack(spacing: 10) {
            activityCell(
                icon: "figure.walk",
                value: healthKit.todaySteps.map { String(format: "%.0f", $0) } ?? "—",
                label: "Steps",
                color: Color(red: 0.20, green: 0.78, blue: 0.35)
            )
            activityCell(
                icon: "flame.fill",
                value: healthKit.todayActiveKcal.map { String(format: "%.0f", $0) } ?? "—",
                label: "Active kcal",
                color: Color(red: 1.00, green: 0.55, blue: 0.26)
            )
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func activityCell(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(.label))
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Weekly schedule picker

    @ViewBuilder
    private var weeklySchedulePicker: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Weekly Plan")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color(.secondaryLabel))
                Spacer()
                HStack(spacing: 10) {
                    ForEach(ScheduledActivity.allCases) { a in
                        HStack(spacing: 3) {
                            Image(systemName: a.icon).font(.system(size: 9))
                            Text(a.label).font(.system(size: 10))
                        }
                        .foregroundStyle(Color(.secondaryLabel))
                    }
                }
            }
            .padding(.horizontal, 16)

            HStack(spacing: 6) {
                ForEach(currentWeekDays, id: \.self) { date in
                    dayCell(for: date)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let key = dateKey(for: date)
        let activity = weeklySchedule[key].flatMap { ScheduledActivity(rawValue: $0) }
        let isToday = Calendar.current.isDateInToday(date)
        let isPast  = date < Calendar.current.startOfDay(for: Date())

        Button { cycleActivity(for: key, current: activity) } label: {
            VStack(spacing: 4) {
                Text(date.formatted(.dateTime.weekday(.narrow)))
                    .font(.system(size: 10, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(isToday ? .white : Color(.secondaryLabel))

                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(isToday ? .white : (isPast ? Color(.tertiaryLabel) : Color(.label)))

                if let activity {
                    Image(systemName: activity.icon)
                        .font(.system(size: 11))
                        .foregroundStyle(isToday ? .white : Color.accentColor)
                } else {
                    Circle()
                        .fill(isToday ? Color.white.opacity(0.4) : Color(.systemGray4))
                        .frame(width: 5, height: 5)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(isToday ? Color.accentColor : Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        activity != nil && !isToday ? Color.accentColor.opacity(0.45) : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func dateKey(for date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    private func cycleActivity(for key: String, current: ScheduledActivity?) {
        var schedule = weeklySchedule
        switch current {
        case nil:      schedule[key] = ScheduledActivity.rest.rawValue
        case .rest:    schedule[key] = ScheduledActivity.run.rawValue
        case .run:     schedule[key] = ScheduledActivity.workout.rawValue
        case .workout: schedule.removeValue(forKey: key)
        }
        if let data = try? JSONEncoder().encode(schedule),
           let json = String(data: data, encoding: .utf8) {
            weeklyScheduleJSON = json
        }
    }

    // MARK: - States

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.4)
            Text("Loading your data…")
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
        }
    }

    @ViewBuilder
    private var noDataView: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 64))
                .foregroundStyle(Color(.tertiaryLabel))

            VStack(spacing: 8) {
                Text("No Data Yet")
                    .font(.title3).bold()
                Text("Wear your Apple Watch overnight and check back tomorrow for your first readiness score.")
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabel))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button("Retry") {
                Task { await healthKit.loadData(baselineDays: baselineDays) }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.slash")
                .font(.system(size: 64))
                .foregroundStyle(Color(.tertiaryLabel))

            VStack(spacing: 8) {
                Text("HealthKit Access Required")
                    .font(.title3).bold()
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabel))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
    }

    // MARK: - Reason text

    private func reasonText(for score: ReadinessScore) -> String {
        var good: [String] = []
        var off:  [String] = []

        if score.todayHRV != nil {
            switch score.hrvScore {
            case  1: good.append("HRV is strong")
            case  0: off.append("HRV is slightly off")
            default: off.append("HRV is low")
            }
        }
        if score.todayRHR != nil {
            switch score.rhrScore {
            case  1: good.append("heart rate is steady")
            case  0: off.append("heart rate is slightly elevated")
            default: off.append("heart rate is elevated")
            }
        }
        if score.todaySleep != nil {
            switch score.sleepScore {
            case  1: good.append("sleep was solid")
            case  0: off.append("sleep was a bit short")
            default: off.append("sleep was short")
            }
        }

        if good.isEmpty && off.isEmpty { return "" }
        if off.isEmpty  { return ucfirst(join(good)) + "." }
        if good.isEmpty { return ucfirst(join(off))  + "." }
        return ucfirst(join(good)) + ", but " + join(off) + "."
    }

    private func join(_ items: [String]) -> String {
        switch items.count {
        case 0:  return ""
        case 1:  return items[0]
        case 2:  return "\(items[0]) and \(items[1])"
        default: return items.dropLast().joined(separator: ", ") + ", and " + items.last!
        }
    }

    private func ucfirst(_ s: String) -> String {
        guard let first = s.first else { return s }
        return first.uppercased() + s.dropFirst()
    }
}
