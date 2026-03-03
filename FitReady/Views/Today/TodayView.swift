import SwiftUI

/// The V2 Today screen: decision-first, low-friction daily guidance.
///
/// Layout (top → bottom):
///   1. WeekCalendarStrip     — "Today" header + profile nav + full week plan badges
///   2. TodayHeroSection      — state + headline + reassurance + reason + "See details"
///   3. PrimaryActionSection  — single recommended workout CTA
///   4. SecondaryActionsSection — Scan meal + mobility/steps
///   5. ReinforcementSection  — momentum ring + win
///   6. CollapsedStatusSection — steps / calories / protein stat cells + tip
///
/// Uses mock data on init; wires to live HealthKit data via `updateFromHealthKit()`.
struct TodayView: View {

    @EnvironmentObject private var healthKit: HealthKitManager
    @StateObject private var vm = TodayViewModel(mockState: .yellow)

    // Scanned meals (fallback when HealthKit nutrition is unavailable)
    @AppStorage("mealsJSON") private var mealsJSON: String = "[]"

    // Settings needed to compute ReadinessScore + MacroTargets
    @AppStorage("baselineDays")          private var baselineDays: Int    = 7
    @AppStorage("sleepTargetHours")      private var sleepTargetHours: Double = 7.5
    @AppStorage("hrvGoodThreshold")      private var hrvGoodThreshold: Double = 0.95
    @AppStorage("hrvNeutralThreshold")   private var hrvNeutralThreshold: Double = 0.80
    @AppStorage("rhrGoodThreshold")      private var rhrGoodThreshold: Double = 1.03
    @AppStorage("rhrNeutralThreshold")   private var rhrNeutralThreshold: Double = 1.08
    @AppStorage("heightCm")             private var heightCm: Double = 0
    @AppStorage("ageYears")             private var ageYears: Int    = 0
    @AppStorage("biologicalSex")        private var biologicalSex: String = ""
    @AppStorage("activityLevel")        private var activityLevel: String = "moderate"
    @AppStorage("weightLossPace")       private var weightLossPace: Double = 0.5
    @AppStorage("proteinPerKg")         private var proteinPerKg: Double = 1.8
    @AppStorage("fatFloorPct")          private var fatFloorPct: Double = 25
    @AppStorage("manualWeightKg")       private var manualWeight: Double = 0
    @AppStorage("useManualWeight")      private var useManualWeight: Bool = false

    // MARK: - Derived

    private var displayWeight: Double? {
        if useManualWeight { return manualWeight > 0 ? manualWeight : nil }
        return healthKit.currentWeightKg
    }

    private var macroTargets: MacroTargets? {
        guard let wt = displayWeight, heightCm > 0, ageYears > 0, !biologicalSex.isEmpty else { return nil }
        return MacroEngine.compute(
            weightKg:      wt,
            heightCm:      heightCm,
            ageYears:      ageYears,
            isMale:        biologicalSex == "male",
            activityLevel: activityLevel,
            paceKgPerWeek: weightLossPace,
            proteinPerKg:  proteinPerKg,
            fatFloorPct:   fatFloorPct
        )
    }

    private var readinessScore: ReadinessScore? {
        guard let today = healthKit.todayMetrics,
              !healthKit.baselineMetrics.isEmpty else { return nil }
        let settings = AppSettings(
            baselineDays:        baselineDays,
            sleepTargetHours:    sleepTargetHours,
            hrvGoodThreshold:    hrvGoodThreshold,
            hrvNeutralThreshold: hrvNeutralThreshold,
            rhrGoodThreshold:    rhrGoodThreshold,
            rhrNeutralThreshold: rhrNeutralThreshold
        )
        return ReadinessEngine.compute(today: today, baseline: healthKit.baselineMetrics, settings: settings)
    }

    private var todayKey: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    /// Totals from scanned/logged meals for today — used as fallback when HealthKit
    /// doesn't have dietary data.
    private var mealTotals: (kcal: Double?, protein: Double?, fat: Double?, carbs: Double?)? {
        guard let meals = try? JSONDecoder().decode([MealEntry].self, from: Data(mealsJSON.utf8)) else { return nil }
        let today = meals.filter { $0.date == todayKey }
        guard !today.isEmpty else { return nil }
        return (
            kcal:    today.reduce(0) { $0 + $1.kcal },
            protein: today.reduce(0) { $0 + $1.proteinG },
            fat:     today.reduce(0) { $0 + $1.fatG },
            carbs:   today.reduce(0) { $0 + $1.carbsG }
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DS.Spacing.xl) {
                        WeekCalendarStrip(vm: vm)
                        TodayHeroSection(vm: vm)
                        PrimaryActionSection(vm: vm)
                        SecondaryActionsSection(vm: vm)
                        ReinforcementSection(vm: vm)
                        CollapsedStatusSection(vm: vm)
                        Spacer(minLength: DS.Spacing.xl)
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.sm)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $vm.detailsSheetVisible) {
                ReadinessDetailsSheet(vm: vm)
            }
        }
        .onAppear            { updateFromHealthKit() }
        .onChange(of: healthKit.todayMetrics)     { _, _ in updateFromHealthKit() }
        .onChange(of: healthKit.baselineMetrics)  { _, _ in updateFromHealthKit() }
        .onChange(of: healthKit.todayKcal)        { _, _ in updateFromHealthKit() }
        .onChange(of: healthKit.todaySteps)       { _, _ in updateFromHealthKit() }
        .onChange(of: healthKit.todayActiveKcal)  { _, _ in updateFromHealthKit() }
        .onChange(of: mealsJSON)                  { _, _ in updateFromHealthKit() }
    }

    // MARK: - HealthKit sync

    private func updateFromHealthKit() {
        guard let score = readinessScore else { return }
        vm.update(from: score, healthKit: healthKit, macroTargets: macroTargets, mealTotals: mealTotals)
    }
}

// MARK: - Previews

#Preview("Yellow state") {
    TodayView()
        .environmentObject(HealthKitManager())
}

#Preview("Green state") {
    let vm = TodayViewModel(mockState: .green)
    return NavigationStack {
        ZStack {
            DS.Background.page.ignoresSafeArea()
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    WeekCalendarStrip(vm: vm)
                    TodayHeroSection(vm: vm)
                    PrimaryActionSection(vm: vm)
                    SecondaryActionsSection(vm: vm)
                    ReinforcementSection(vm: vm)
                    CollapsedStatusSection(vm: vm)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.sm)
            }
        }
    }
}

#Preview("Red state") {
    let vm = TodayViewModel(mockState: .red)
    return NavigationStack {
        ZStack {
            DS.Background.page.ignoresSafeArea()
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    WeekCalendarStrip(vm: vm)
                    TodayHeroSection(vm: vm)
                    PrimaryActionSection(vm: vm)
                    SecondaryActionsSection(vm: vm)
                    ReinforcementSection(vm: vm)
                    CollapsedStatusSection(vm: vm)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.sm)
            }
        }
    }
}
