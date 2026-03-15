import SwiftUI
import HealthKit

// MARK: - Unified timeline entry

private enum TimelineEntry: Identifiable {
    case meal(MealEntry)
    case workout(HKWorkout)

    var id: String {
        switch self {
        case .meal(let m):    return m.id.uuidString
        case .workout(let w): return w.uuid.uuidString
        }
    }

    var timestamp: Date {
        switch self {
        case .meal(let m):    return m.timestamp
        case .workout(let w): return w.startDate
        }
    }
}

struct FoodView: View {

    @EnvironmentObject private var healthKit: HealthKitManager

    // ── Profile inputs for BMR ────────────────────────
    @AppStorage("heightCm")       private var heightCm: Double = 0
    @AppStorage("ageYears")       private var ageYears: Int    = 0
    @AppStorage("biologicalSex")  private var biologicalSex: String = ""

    // ── Macro settings ────────────────────────────────
    @AppStorage("activityLevel")    private var activityLevel: String = "moderate"
    @AppStorage("weightLossPace")   private var weightLossPace: Double = 0.5
    @AppStorage("proteinPerKg")     private var proteinPerKg: Double = 1.8
    @AppStorage("fatFloorPct")      private var fatFloorPct: Double = 25

    // ── Weight (reuse existing key) ───────────────────
    @AppStorage("manualWeightKg")   private var manualWeight: Double = 0
    @AppStorage("useManualWeight")  private var useManualWeight: Bool = false

    // ── Manual intake fallback ────────────────────────
    @AppStorage("manualKcal")       private var manualKcal: Double = 0
    @AppStorage("manualProteinG")   private var manualProteinG: Double = 0
    @AppStorage("manualFatG")       private var manualFatG: Double = 0
    @AppStorage("manualCarbsG")     private var manualCarbsG: Double = 0
    @AppStorage("manualMacroDate")  private var manualMacroDate: String = ""

    // ── Meal log (scanner) ────────────────────────────
    @AppStorage("mealsJSON")        private var mealsJSON: String = "[]"
    @AppStorage("anthropicAPIKey")  private var apiKey: String = ""

    // ── Setup form state ──────────────────────────────
    @State private var heightText: String = ""
    @State private var ageText: String = ""

    // ── Manual entry state ────────────────────────────
    @State private var manualKcalText: String = ""
    @State private var manualProteinText: String = ""
    @State private var manualFatText: String = ""
    @State private var manualCarbsText: String = ""
    @FocusState private var focusedField: ManualField?

    // ── Scanner state ─────────────────────────────────
    @State private var showingScanner = false
    @State private var showingManualEntryInline = false

    private enum ManualField { case kcal, protein, fat, carbs }

    // ── Computed ──────────────────────────────────────

    private var currentWeight: Double? {
        if useManualWeight { return manualWeight > 0 ? manualWeight : nil }
        return healthKit.currentWeightKg ?? (manualWeight > 0 ? manualWeight : nil)
    }

    private var isSetupComplete: Bool {
        heightCm > 0 && ageYears > 0 && !biologicalSex.isEmpty
    }

    private var macroTargets: MacroTargets? {
        guard isSetupComplete, let w = currentWeight else { return nil }
        return MacroEngine.compute(
            weightKg:          w,
            heightCm:          heightCm,
            ageYears:          ageYears,
            isMale:            biologicalSex == "male",
            activityLevel:     activityLevel,
            paceKgPerWeek:     weightLossPace,
            proteinPerKg:      proteinPerKg,
            fatFloorPct:       fatFloorPct
        )
    }

    private var todayKey: String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    private var todayMeals: [MealEntry] {
        ((try? JSONDecoder().decode([MealEntry].self, from: Data(mealsJSON.utf8))) ?? [])
            .filter { $0.date == todayKey }
    }

    /// Returns today's intake. Priority: HealthKit → logged meals → old manual total.
    private var intake: (kcal: Double?, protein: Double?, fat: Double?, carbs: Double?) {
        if healthKit.todayKcal != nil {
            return (healthKit.todayKcal, healthKit.todayProteinG, healthKit.todayFatG, healthKit.todayCarbsG)
        }
        if !todayMeals.isEmpty {
            return (
                todayMeals.reduce(0) { $0 + $1.kcal },
                todayMeals.reduce(0) { $0 + $1.proteinG },
                todayMeals.reduce(0) { $0 + $1.fatG },
                todayMeals.reduce(0) { $0 + $1.carbsG }
            )
        }
        if manualMacroDate == todayKey && manualKcal > 0 {
            return (manualKcal, manualProteinG > 0 ? manualProteinG : nil,
                    manualFatG > 0 ? manualFatG : nil, manualCarbsG > 0 ? manualCarbsG : nil)
        }
        return (nil, nil, nil, nil)
    }

    private var showManualEntry: Bool {
        healthKit.todayKcal == nil
    }

    /// All today's meals and workouts merged and sorted chronologically.
    private var todayTimelineEntries: [TimelineEntry] {
        let mealEntries = todayMeals.map { TimelineEntry.meal($0) }
        let workoutEntries = healthKit.todayWorkouts.map { TimelineEntry.workout($0) }
        return (mealEntries + workoutEntries).sorted { $0.timestamp < $1.timestamp }
    }

    private let macroColors: [(Color, String)] = [
        (AppColors.dataCalories, "kcal"),
        (AppColors.dataProtein,  "protein"),
        (AppColors.dataFat,      "fat"),
        (AppColors.dataCarbs,    "carbs"),
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        if !isSetupComplete || currentWeight == nil {
                            setupCard
                        } else if let targets = macroTargets {
                            caloriesLeftCard(targets: targets)
                            if showManualEntry {
                                mealLogCard
                            }
                        }
                    }
                    .padding()
                }
                .onTapGesture { focusedField = nil }
            }
            .navigationTitle("Food")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingScanner) {
                FoodScannerSheet(
                    apiKey: apiKey,
                    todayKey: todayKey,
                    onSave: { entry in saveMealEntry(entry) }
                )
            }
        }
    }

    // MARK: - Setup card

    @ViewBuilder
    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Set Up Your Macros", systemImage: "fork.knife.circle.fill")
                    .font(.headline)
                Text("Enter a few details so FitReady can calculate your ideal daily calories, protein, fat and carbs.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Divider()

            // Height
            VStack(alignment: .leading, spacing: 8) {
                Text("Height").font(.subheadline).fontWeight(.semibold)
                HStack {
                    TextField("e.g. 178", text: $heightText)
                        .keyboardType(.numberPad)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("cm").font(.title3).foregroundStyle(AppColors.textSecondary)
                }
            }

            // Age
            VStack(alignment: .leading, spacing: 8) {
                Text("Age").font(.subheadline).fontWeight(.semibold)
                HStack {
                    TextField("e.g. 32", text: $ageText)
                        .keyboardType(.numberPad)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("years").font(.title3).foregroundStyle(AppColors.textSecondary)
                }
            }

            // Sex
            VStack(alignment: .leading, spacing: 8) {
                Text("Biological Sex").font(.subheadline).fontWeight(.semibold)
                Picker("Sex", selection: $biologicalSex) {
                    Text("Male").tag("male")
                    Text("Female").tag("female")
                }
                .pickerStyle(.segmented)
            }

            Button("Calculate My Macros") {
                saveSetup()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.accent)
            .disabled(heightText.isEmpty || ageText.isEmpty || biologicalSex.isEmpty)
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppColors.shadowColor, radius: 8, x: 0, y: 2)
        .onAppear {
            if heightCm > 0 { heightText = String(Int(heightCm)) }
            if ageYears > 0 { ageText    = String(ageYears) }
            if biologicalSex.isEmpty { biologicalSex = "male" }
        }
    }

    // MARK: - Calories Left card

    @ViewBuilder
    private func caloriesLeftCard(targets: MacroTargets) -> some View {
        let i = intake
        let kcalConsumed = Int(i.kcal ?? 0)
        let kcalLeft     = targets.kcal - kcalConsumed
        let isOver       = kcalLeft < 0
        let carbsG       = Int(i.carbs   ?? 0)
        let proteinG     = Int(i.protein ?? 0)
        let fatG         = Int(i.fat     ?? 0)

        let carbsKcal   = Double(carbsG)   * 4
        let proteinKcal = Double(proteinG) * 4
        let fatKcal     = Double(fatG)     * 9
        let totalKcal   = carbsKcal + proteinKcal + fatKcal

        VStack(alignment: .leading, spacing: 16) {
            // Section label chip
            Text(isOver ? "OVER TARGET" : "CALORIES TODAY")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isOver ? AppColors.danger : AppColors.accentGold)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, 3)
                .background((isOver ? AppColors.danger : AppColors.accentGold).opacity(0.15))
                .clipShape(Capsule())

            // Large calorie number — current / target
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formatCalories(kcalConsumed))
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(isOver ? AppColors.danger : .white)
                Text("/ \(formatCalories(targets.kcal)) kcal")
                    .font(DS.Typography.title())
                    .foregroundStyle(AppColors.iconOnDark.opacity(0.7))
            }

            // Macro bar
            macroBar(carbsKcal: carbsKcal, proteinKcal: proteinKcal, fatKcal: fatKcal, consumed: totalKcal, target: Double(targets.kcal))
                .frame(height: 8)

            Divider()
                .opacity(0.3)

            // Macro rows
            macroRow(color: AppColors.dataCarbs, label: "Carbohydrates", value: carbsG, target: targets.carbsG)
            macroRow(color: AppColors.dataProtein, label: "Protein", value: proteinG, target: targets.proteinG)
            macroRow(color: AppColors.dataFat, label: "Fat", value: fatG, target: targets.fatG)
        }
        .padding(16)
        .background(Color(red: 0.125, green: 0.259, blue: 0.18))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppColors.shadowColor, radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private func macroBar(carbsKcal: Double, proteinKcal: Double, fatKcal: Double, consumed: Double, target: Double) -> some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                if consumed > 0 && target > 0 {
                    // Each macro's width as proportion of total target
                    let carbsWidth = max(1, geo.size.width * (carbsKcal / target))
                    let proteinWidth = max(1, geo.size.width * (proteinKcal / target))
                    let fatWidth = max(1, geo.size.width * (fatKcal / target))
                    let remainingWidth = max(0, geo.size.width * ((target - consumed) / target))

                    if carbsKcal > 0 {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppColors.dataCarbs)
                            .frame(width: carbsWidth)
                    }
                    if proteinKcal > 0 {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppColors.dataProtein)
                            .frame(width: proteinWidth)
                    }
                    if fatKcal > 0 {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppColors.dataFat)
                            .frame(width: fatWidth)
                    }

                    // Remaining unfilled portion
                    if remainingWidth > 0 {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppColors.metricInactive)
                    }
                } else {
                    // Empty bar (no consumption)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.metricInactive)
                }
            }
        }
    }

    @ViewBuilder
    private func macroRow(color: Color, label: String, value: Int, target: Int) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white)
            Spacer()
            HStack(spacing: 2) {
                Text("\(value)")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                Text("/ \(target)")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
            }
            .foregroundStyle(AppColors.iconOnDark.opacity(0.7))
        }
    }

    // MARK: - Meal log card (timeline + manual)

    @ViewBuilder
    private var mealLogCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {

            // Header + Scan button
            HStack {
                Text("TODAY'S MEALS")
                    .font(DS.Typography.label())
                    .foregroundStyle(AppColors.textSecondary)
                    .kerning(0.5)
                Spacer()
                Button {
                    showingScanner = true
                } label: {
                    Label("Log meal", systemImage: "camera.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, DS.Spacing.md).padding(.vertical, 6)
                        .background(AppColors.brandPrimary)
                        .foregroundStyle(AppColors.textOnBrand)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // Meal + workout timeline
            if todayTimelineEntries.isEmpty {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "fork.knife.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(AppColors.textMuted)
                    Text("No meals logged yet. Scan a photo or add manually.")
                        .font(DS.Typography.caption())
                        .foregroundStyle(AppColors.textMuted)
                }
                .padding(.vertical, DS.Spacing.sm)
            } else {
                mealTimeline
            }

            Divider()

            // Add manually toggle
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showingManualEntryInline.toggle()
                }
            } label: {
                Label(showingManualEntryInline ? "Hide manual entry" : "Add manually",
                      systemImage: showingManualEntryInline ? "chevron.up" : "plus")
                    .font(DS.Typography.caption())
                    .foregroundStyle(AppColors.textSecondary)
            }
            .buttonStyle(.plain)

            if showingManualEntryInline {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    manualField(label: "Calories (kcal)", text: $manualKcalText, field: .kcal)
                    manualField(label: "Protein (g)",     text: $manualProteinText, field: .protein)
                    manualField(label: "Fat (g)",         text: $manualFatText, field: .fat)
                    manualField(label: "Carbs (g)",       text: $manualCarbsText, field: .carbs)
                }

                Button("Log Manual Entry") {
                    saveManualAsMealEntry()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.accent)
                .disabled(manualKcalText.isEmpty)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(DS.Spacing.lg)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
        .overlay(RoundedRectangle(cornerRadius: DS.Corner.card).strokeBorder(DS.Border.color, lineWidth: 1))
        .shadow(color: AppColors.shadowColor, radius: DS.Shadow.radius, x: 0, y: DS.Shadow.y)
    }

    /// Visual timeline of today's meals and workouts, sorted chronologically.
    @ViewBuilder
    private var mealTimeline: some View {
        let entries = todayTimelineEntries
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { idx, entry in
                HStack(alignment: .top, spacing: DS.Spacing.sm) {

                    // Timeline rail
                    VStack(spacing: 0) {
                        timelineRailIcon(entry: entry)
                            .padding(.top, 5)

                        if idx < entries.count - 1 {
                            Rectangle()
                                .fill(DS.Border.color)
                                .frame(width: 1)
                                .frame(maxHeight: .infinity)
                                .padding(.vertical, 2)
                        }
                    }
                    .frame(width: 32)

                    // Row content
                    switch entry {
                    case .meal(let meal):
                        mealRow(meal: meal, isLast: idx == entries.count - 1)
                    case .workout(let workout):
                        workoutRow(workout: workout, isLast: idx == entries.count - 1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func timelineRailIcon(entry: TimelineEntry) -> some View {
        switch entry {
        case .meal:
            ZStack {
                Circle()
                    .fill(AppColors.accentGold.opacity(0.18))
                    .frame(width: 28, height: 28)
                Image(systemName: "fork.knife")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
            }
        case .workout(let workout):
            ZStack {
                Circle()
                    .fill(AppColors.accentGold.opacity(0.18))
                    .frame(width: 28, height: 28)
                Image(systemName: workoutSymbol(for: workout.workoutActivityType))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
            }
        }
    }

    @ViewBuilder
    private func mealRow(meal: MealEntry, isLast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: DS.Spacing.xs) {
                Text(meal.timestamp.formatted(.dateTime.hour().minute()))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppColors.textMuted)

                Image(systemName: meal.source == "scan" ? "camera.fill" : "pencil")
                    .font(.system(size: 9))
                    .foregroundStyle(AppColors.textMuted)
            }

            Text(meal.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)

            HStack(spacing: DS.Spacing.sm) {
                mealMacroChip(value: Int(meal.kcal),      unit: "kcal", color: AppColors.dataCalories)
                mealMacroChip(value: Int(meal.proteinG),  unit: "P",    color: AppColors.dataProtein)
                mealMacroChip(value: Int(meal.carbsG),    unit: "C",    color: AppColors.dataCarbs)
                mealMacroChip(value: Int(meal.fatG),      unit: "F",    color: AppColors.dataFat)

                Spacer()

                Button {
                    deleteMealEntry(id: meal.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, isLast ? 0 : DS.Spacing.md)
    }

    @ViewBuilder
    private func workoutRow(workout: HKWorkout, isLast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(workout.startDate.formatted(.dateTime.hour().minute()))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppColors.textMuted)

            Text(workoutTypeName(for: workout.workoutActivityType))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)

            Text(workoutSubtitle(for: workout))
                .font(DS.Typography.caption())
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.bottom, isLast ? 0 : DS.Spacing.md)
    }

    private func workoutSymbol(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running:                                    return "figure.run"
        case .walking:                                    return "figure.walk"
        case .cycling:                                    return "figure.outdoor.cycle"
        case .traditionalStrengthTraining,
             .functionalStrengthTraining,
             .coreTraining,
             .crossTraining:                             return "figure.strengthtraining.traditional"
        default:                                         return "bolt.heart"
        }
    }

    private func workoutTypeName(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running:                          return "Run"
        case .walking:                          return "Walk"
        case .cycling:                          return "Cycling"
        case .swimming:                         return "Swimming"
        case .yoga:                             return "Yoga"
        case .hiking:                           return "Hike"
        case .traditionalStrengthTraining:      return "Strength Training"
        case .functionalStrengthTraining:       return "Functional Strength"
        case .coreTraining:                     return "Core Training"
        case .crossTraining:                    return "Cross Training"
        case .highIntensityIntervalTraining:    return "HIIT"
        case .elliptical:                       return "Elliptical"
        case .rowing:                           return "Rowing"
        case .stairClimbing:                    return "Stair Climbing"
        case .pilates:                          return "Pilates"
        case .dance:                            return "Dance"
        case .soccer:                           return "Football"
        case .basketball:                       return "Basketball"
        case .tennis:                           return "Tennis"
        default:                                return "Workout"
        }
    }

    private func workoutSubtitle(for workout: HKWorkout) -> String {
        let minutes = Int(workout.duration / 60)
        let durationText = "\(minutes) min"
        if let kcalQuantity = workout.totalEnergyBurned {
            let kcal = Int(kcalQuantity.doubleValue(for: .kilocalorie()))
            if kcal > 0 { return "\(durationText) · \(kcal) kcal" }
        }
        return durationText
    }

    @ViewBuilder
    private func mealMacroChip(value: Int, unit: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(unit)
                .font(.system(size: 10))
                .foregroundStyle(AppColors.textMuted)
        }
    }

    @ViewBuilder
    private func manualField(label: String, text: Binding<String>, field: ManualField) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: field)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .padding(10)
                .background(AppColors.background)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Reusable sub-views

    // MARK: - Helpers

    private func formatCalories(_ value: Int) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        return fmt.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func paceLabel(_ pace: Double) -> String {
        pace == 0 ? "Maintain" : String(format: "−%.2g kg/wk", pace)
    }

    private func saveSetup() {
        if let h = Double(heightText.replacingOccurrences(of: ",", with: ".")) { heightCm = h }
        if let a = Int(ageText)                                                  { ageYears = a }
    }

    private func saveManualIntake() {
        if let v = Double(manualKcalText)    { manualKcal     = v }
        if let v = Double(manualProteinText) { manualProteinG = v }
        if let v = Double(manualFatText)     { manualFatG     = v }
        if let v = Double(manualCarbsText)   { manualCarbsG   = v }
        manualMacroDate = todayKey
        focusedField    = nil
    }

    private func saveManualAsMealEntry() {
        let entry = MealEntry(
            date:     todayKey,
            name:     "Manual entry",
            kcal:     Double(manualKcalText)    ?? 0,
            proteinG: Double(manualProteinText) ?? 0,
            fatG:     Double(manualFatText)     ?? 0,
            carbsG:   Double(manualCarbsText)   ?? 0,
            source:   "manual"
        )
        saveMealEntry(entry)
        manualKcalText    = ""
        manualProteinText = ""
        manualFatText     = ""
        manualCarbsText   = ""
        focusedField      = nil
        withAnimation { showingManualEntryInline = false }
    }

    func saveMealEntry(_ entry: MealEntry) {
        var meals = (try? JSONDecoder().decode([MealEntry].self, from: Data(mealsJSON.utf8))) ?? []
        meals.append(entry)
        if let data = try? JSONEncoder().encode(meals),
           let json = String(data: data, encoding: .utf8) { mealsJSON = json }
    }

    private func deleteMealEntry(id: UUID) {
        var meals = (try? JSONDecoder().decode([MealEntry].self, from: Data(mealsJSON.utf8))) ?? []
        meals.removeAll { $0.id == id }
        if let data = try? JSONEncoder().encode(meals),
           let json = String(data: data, encoding: .utf8) { mealsJSON = json }
    }
}
