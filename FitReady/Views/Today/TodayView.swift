import SwiftUI

/// The V2 Today screen: decision-first, low-friction daily guidance.
///
/// Layout (top → bottom):
///   1. TodayHeroSection      — state + headline + reassurance + reason + "See details"
///   2. PrimaryActionSection  — single recommended workout CTA
///   3. SecondaryActionsSection — Log meal + mobility/steps
///   4. ReinforcementSection  — momentum ring + win
///   5. CollapsedStatusSection — steps / active kcal / protein chips (expandable)
///
/// Uses mock data on init; wires to live HealthKit data via `updateFromHealthKit()`.
struct TodayView: View {

    @EnvironmentObject private var healthKit: HealthKitManager
    @StateObject private var vm = TodayViewModel(mockState: .yellow)

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

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DS.Spacing.xl) {
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
        .onChange(of: healthKit.todayMetrics)    { _, _ in updateFromHealthKit() }
        .onChange(of: healthKit.todayKcal)       { _, _ in updateFromHealthKit() }
        .onChange(of: healthKit.todaySteps)      { _, _ in updateFromHealthKit() }
        .onChange(of: healthKit.todayActiveKcal) { _, _ in updateFromHealthKit() }
    }

    // MARK: - HealthKit sync

    private func updateFromHealthKit() {
        guard let score = readinessScore else { return }
        vm.update(from: score, healthKit: healthKit, macroTargets: macroTargets)
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
