import SwiftUI

/// The V2 Today screen: a daily decision system, not a dashboard.
///
/// Layout (top → bottom):
///   1. Greeting header             — "Good morning Michel" + profile avatar
///   2. TodayHeroSection            — decision chip + headline + reason + two CTAs
///   3. RecoveryCarouselSection     — swipe carousel of recovery exercises
///   4. CollapsedStatusSection      — "Steps & Nutrition" card with progress rings
///   5. ReinforcementSection        — "Momentum" weekly consistency card
struct TodayView: View {

    @EnvironmentObject private var healthKit: HealthKitManager
    @StateObject private var vm = TodayViewModel(mockState: .yellow)

    // Scanned meals (fallback when HealthKit nutrition is unavailable)
    @AppStorage("mealsJSON")             private var mealsJSON: String = "[]"
    @AppStorage("anthropicAPIKey")       private var apiKey:    String = ""

    // Weekly plan — used to derive today's planned day type
    @AppStorage("weeklyPlan")            private var weeklyPlan: String = "W,L,W,L,W,R,R"

    @AppStorage("notificationLevel")     private var notificationLevel: String = "moderate"

    // Profile
    @AppStorage("profileName")           private var profileName:     String = ""
    @AppStorage("profilePhotoData")      private var profilePhotoData: Data  = Data()

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

    /// Live TDEE = BMR + Apple Watch active kcal — matches the Food tab calculation.
    private var liveTDEE: Double? {
        guard let wt = displayWeight, heightCm > 0, ageYears > 0, !biologicalSex.isEmpty,
              let neat = healthKit.todayActiveKcal else { return nil }
        let bmr = MacroEngine.bmr(weightKg: wt, heightCm: heightCm, ageYears: ageYears,
                                  isMale: biologicalSex == "male")
        return bmr + neat
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
            fatFloorPct:   fatFloorPct,
            tdeeOverride:  liveTDEE
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

    /// Today's planned day type ("W", "L", or "R") from the weekly plan template.
    private var todayPlanLetter: String {
        let parts = weeklyPlan.components(separatedBy: ",")
        guard parts.count == 7 else { return "W" }
        let weekday = Calendar.current.component(.weekday, from: Date()) // 1=Sun … 7=Sat
        let mondayIndex = (weekday - 2 + 7) % 7
        return parts[min(mondayIndex, 6)]
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

    /// Time-aware greeting ("Good morning", "Good afternoon", "Good evening").
    private var greetingPrefix: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    private var greetingText: String {
        profileName.isEmpty ? greetingPrefix : "\(greetingPrefix) \(profileName)"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DS.Spacing.xl) {

                        // — Greeting header —
                        greetingHeader

                        // — Hero: daily decision —
                        TodayHeroSection(vm: vm)

                        // — Recovery exercise carousel —
                        RecoveryCarouselSection()

                        // — Next Win: nutrition / steps —
                        CollapsedStatusSection(vm: vm)

                        // — Momentum: weekly consistency —
                        ReinforcementSection(vm: vm)

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
            .sheet(isPresented: $vm.showingScanner) {
                FoodScannerSheet(apiKey: apiKey, todayKey: todayKey) { entry in
                    saveMealEntry(entry)
                }
            }
        }
        .onAppear            { updateFromHealthKit() }
        .onChange(of: healthKit.todayMetrics)     { _, _ in updateFromHealthKit() }
        .onChange(of: healthKit.baselineMetrics)  { _, _ in updateFromHealthKit() }
        .onChange(of: healthKit.todayKcal)        { _, _ in updateFromHealthKit() }
        .onChange(of: healthKit.todayProteinG)    { _, _ in updateFromHealthKit() }
        .onChange(of: healthKit.todaySteps)       { _, _ in updateFromHealthKit() }
        .onChange(of: healthKit.todayActiveKcal)  { _, _ in updateFromHealthKit() }
        .onChange(of: healthKit.weeklySteps)      { _, _ in updateFromHealthKit() }
        .onChange(of: mealsJSON)                  { _, _ in updateFromHealthKit() }
        .onChange(of: weeklyPlan)                 { _, _ in updateFromHealthKit() }
    }

    // MARK: - Greeting header

    private var greetingHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greetingText)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(DS.Typography.caption())
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            NavigationLink(destination: ProfileView()) {
                profileAvatar
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var profileAvatar: some View {
        if !profilePhotoData.isEmpty, let img = UIImage(data: profilePhotoData) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: 42, height: 42)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .foregroundStyle(AppColors.textMuted)
                .frame(width: 42, height: 42)
        }
    }

    // MARK: - HealthKit sync

    private func updateFromHealthKit() {
        guard let score = readinessScore else { return }
        vm.update(from: score, healthKit: healthKit, macroTargets: macroTargets,
                  mealTotals: mealTotals, planLetter: todayPlanLetter,
                  weeklySteps: healthKit.weeklySteps)
        NotificationManager.shared.sendRecoveryAlertIfNeeded(
            state: vm.readinessState, level: notificationLevel)
    }

    // MARK: - Meal persistence

    private func saveMealEntry(_ entry: MealEntry) {
        var meals = (try? JSONDecoder().decode([MealEntry].self, from: Data(mealsJSON.utf8))) ?? []
        meals.append(entry)
        if let data = try? JSONEncoder().encode(meals),
           let json = String(data: data, encoding: .utf8) { mealsJSON = json }
    }
}

// MARK: - Previews

#Preview("Yellow state") {
    TodayView()
        .environmentObject(HealthKitManager())
}

#Preview("Green state") {
    let vm = TodayViewModel(mockState: .green)
    NavigationStack {
        ZStack {
            DS.Background.page.ignoresSafeArea()
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    TodayHeroSection(vm: vm)
                    RecoveryCarouselSection()
                    CollapsedStatusSection(vm: vm)
                    ReinforcementSection(vm: vm)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.sm)
            }
        }
    }
}

#Preview("Red state") {
    let vm = TodayViewModel(mockState: .red)
    NavigationStack {
        ZStack {
            DS.Background.page.ignoresSafeArea()
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    TodayHeroSection(vm: vm)
                    RecoveryCarouselSection()
                    CollapsedStatusSection(vm: vm)
                    ReinforcementSection(vm: vm)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.sm)
            }
        }
    }
}
