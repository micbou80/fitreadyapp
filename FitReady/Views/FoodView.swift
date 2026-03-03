import SwiftUI

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
    @State private var showingSettings = false

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
                            targetSummaryCard(targets: targets)
                            progressRingsCard(targets: targets)
                            if showManualEntry {
                                mealLogCard
                            }
                            settingsCard
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
                    .foregroundStyle(Color(.secondaryLabel))
            }

            Divider()

            // Height
            VStack(alignment: .leading, spacing: 8) {
                Text("Height").font(.subheadline).fontWeight(.semibold)
                HStack {
                    TextField("e.g. 178", text: $heightText)
                        .keyboardType(.numberPad)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("cm").font(.title3).foregroundStyle(Color(.secondaryLabel))
                }
            }

            // Age
            VStack(alignment: .leading, spacing: 8) {
                Text("Age").font(.subheadline).fontWeight(.semibold)
                HStack {
                    TextField("e.g. 32", text: $ageText)
                        .keyboardType(.numberPad)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("years").font(.title3).foregroundStyle(Color(.secondaryLabel))
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

            // Activity level
            VStack(alignment: .leading, spacing: 8) {
                Text("Activity Level").font(.subheadline).fontWeight(.semibold)
                activityPicker
            }

            // Pace
            VStack(alignment: .leading, spacing: 8) {
                Text("Weight-loss Pace").font(.subheadline).fontWeight(.semibold)
                pacePicker
            }

            // Protein target
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Protein Target").font(.subheadline).fontWeight(.semibold)
                    Spacer()
                    Text(String(format: "%.1f g / kg", proteinPerKg))
                        .font(.subheadline).foregroundStyle(AppColors.dataProtein)
                }
                Slider(value: $proteinPerKg, in: 1.4...2.4, step: 0.1)
                    .tint(AppColors.dataProtein)
            }

            // Fat floor
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Minimum Fat").font(.subheadline).fontWeight(.semibold)
                    Spacer()
                    Text(String(format: "%.0f%% of calories", fatFloorPct))
                        .font(.subheadline).foregroundStyle(AppColors.dataFat)
                }
                Slider(value: $fatFloorPct, in: 20...35, step: 1)
                    .tint(AppColors.dataFat)
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
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppColors.shadowColor, radius: 8, x: 0, y: 2)
        .onAppear {
            if heightCm > 0 { heightText = String(Int(heightCm)) }
            if ageYears > 0 { ageText    = String(ageYears) }
            if biologicalSex.isEmpty { biologicalSex = "male" }
        }
    }

    // MARK: - Target summary card

    @ViewBuilder
    private func targetSummaryCard(targets: MacroTargets) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Daily Targets", systemImage: "target")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color(.secondaryLabel))
                Spacer()
                Text("\(targets.kcal)")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(AppColors.dataCalories)
                + Text(" kcal")
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabel))
            }

            HStack(spacing: 0) {
                macroChip(value: "\(targets.proteinG)g", label: "protein",
                          color: AppColors.dataProtein)
                Text(" · ").foregroundStyle(Color(.tertiaryLabel))
                macroChip(value: "\(targets.fatG)g", label: "fat",
                          color: AppColors.dataFat)
                Text(" · ").foregroundStyle(Color(.tertiaryLabel))
                macroChip(value: "\(targets.carbsG)g", label: "carbs",
                          color: AppColors.dataCarbs)
            }
            .font(.subheadline)

            Divider()

            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.caption)
                Text("\(MacroEngine.levelLabel(for: activityLevel)) · \(paceLabel(weightLossPace))")
                    .font(.caption)
            }
            .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(16)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppColors.shadowColor, radius: 8, x: 0, y: 2)
    }

    // MARK: - Progress rings card

    @ViewBuilder
    private func progressRingsCard(targets: MacroTargets) -> some View {
        let i = intake
        let data: [(label: String, actual: Double?, target: Int, color: Color, unit: String)] = [
            ("Calories", i.kcal,    targets.kcal,     AppColors.dataCalories, "kcal"),
            ("Protein",  i.protein, targets.proteinG, AppColors.dataProtein,  "g"),
            ("Fat",      i.fat,     targets.fatG,     AppColors.dataFat,      "g"),
            ("Carbs",    i.carbs,   targets.carbsG,   AppColors.dataCarbs,    "g"),
        ]

        VStack(alignment: .leading, spacing: 14) {
            Label("Today's Intake", systemImage: "chart.pie.fill")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(Color(.secondaryLabel))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(data.indices, id: \.self) { idx in
                    macroRingCell(
                        label:  data[idx].label,
                        actual: data[idx].actual,
                        target: data[idx].target,
                        color:  data[idx].color,
                        unit:   data[idx].unit
                    )
                }
            }
        }
        .padding(16)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppColors.shadowColor, radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private func macroRingCell(
        label: String,
        actual: Double?,
        target: Int,
        color: Color,
        unit: String
    ) -> some View {
        let progress = actual.map { min(1.0, $0 / Double(max(1, target))) } ?? 0
        let pct      = Int((progress * 100).rounded())

        VStack(spacing: 10) {
            ZStack {
                // Track
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 10)
                // Arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [color.opacity(0.5), color],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8, dampingFraction: 0.75), value: progress)
                // Center
                VStack(spacing: 1) {
                    if let a = actual {
                        Text(unit == "kcal" ? "\(Int(a.rounded()))" : String(format: "%.0f", a))
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color(.label))
                        Text("\(pct)%")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(color)
                    } else {
                        Text("—")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                }
            }
            .frame(width: 90, height: 90)

            VStack(spacing: 2) {
                Text(label)
                    .font(.subheadline).fontWeight(.semibold)
                Text("/ \(target) \(unit)")
                    .font(.caption)
                    .foregroundStyle(Color(.tertiaryLabel))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Meal log card (scanner + manual)

    @ViewBuilder
    private var mealLogCard: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Header + Scan button
            HStack {
                Label("Today's Meals", systemImage: "fork.knife")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color(.secondaryLabel))
                Spacer()
                Button {
                    showingScanner = true
                } label: {
                    Label("Scan", systemImage: "camera.fill")
                        .font(.subheadline).fontWeight(.semibold)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(AppColors.accent)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // Logged meals list
            if todayMeals.isEmpty {
                Text("No meals logged yet. Scan a photo or add manually.")
                    .font(.caption)
                    .foregroundStyle(Color(.tertiaryLabel))
            } else {
                VStack(spacing: 8) {
                    ForEach(todayMeals) { meal in
                        mealRow(meal)
                    }
                }
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
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabel))
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
        .padding(16)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppColors.shadowColor, radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private func mealRow(_ meal: MealEntry) -> some View {
        HStack(spacing: 10) {
            // Source icon
            Image(systemName: meal.source == "scan" ? "camera.fill" : "pencil")
                .font(.system(size: 11))
                .foregroundStyle(AppColors.accent)
                .frame(width: 22, height: 22)
                .background(AppColors.accent.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(meal.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(meal.timestamp.formatted(.dateTime.hour().minute()))
                    .font(.caption2)
                    .foregroundStyle(Color(.tertiaryLabel))
            }

            Spacer()

            // Macro chips
            HStack(spacing: 6) {
                mealMacroChip(value: Int(meal.kcal), unit: "kcal",
                              color: AppColors.dataCalories)
                mealMacroChip(value: Int(meal.proteinG), unit: "P",
                              color: AppColors.dataProtein)
            }

            // Delete button
            Button {
                deleteMealEntry(id: meal.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(AppColors.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func mealMacroChip(value: Int, unit: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(unit)
                .font(.system(size: 10))
                .foregroundStyle(Color(.tertiaryLabel))
        }
    }

    @ViewBuilder
    private func manualField(label: String, text: Binding<String>, field: ManualField) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Color(.secondaryLabel))
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: field)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .padding(10)
                .background(AppColors.background)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Settings card

    @ViewBuilder
    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Macro Settings", systemImage: "slider.horizontal.3")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color(.secondaryLabel))
                Spacer()
                Button(showingSettings ? "Done" : "Edit") {
                    withAnimation(.spring(response: 0.35)) { showingSettings.toggle() }
                }
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(AppColors.accent)
            }

            if showingSettings {
                Divider()

                // Activity
                VStack(alignment: .leading, spacing: 8) {
                    Text("Activity Level").font(.subheadline).fontWeight(.semibold)
                    activityPicker
                }

                // Pace
                VStack(alignment: .leading, spacing: 8) {
                    Text("Weight-loss Pace").font(.subheadline).fontWeight(.semibold)
                    pacePicker
                }

                // Protein
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Protein Target").font(.subheadline).fontWeight(.semibold)
                        Spacer()
                        Text(String(format: "%.1f g/kg", proteinPerKg))
                            .font(.subheadline)
                            .foregroundStyle(AppColors.dataProtein)
                    }
                    Slider(value: $proteinPerKg, in: 1.4...2.4, step: 0.1)
                        .tint(AppColors.dataProtein)
                }

                // Fat floor
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Min Fat").font(.subheadline).fontWeight(.semibold)
                        Spacer()
                        Text(String(format: "%.0f%% of kcal", fatFloorPct))
                            .font(.subheadline)
                            .foregroundStyle(AppColors.dataFat)
                    }
                    Slider(value: $fatFloorPct, in: 20...35, step: 1)
                        .tint(AppColors.dataFat)
                }

                // Reset setup
                Button(role: .destructive) {
                    heightCm      = 0
                    ageYears      = 0
                    biologicalSex = ""
                    heightText    = ""
                    ageText       = ""
                    showingSettings = false
                } label: {
                    Label("Reset Setup", systemImage: "arrow.counterclockwise")
                        .font(.subheadline)
                }
            } else {
                // Compact summary row
                HStack(spacing: 12) {
                    summaryChip(icon: "figure.walk", label: MacroEngine.levelLabel(for: activityLevel))
                    summaryChip(icon: "scalemass", label: paceLabel(weightLossPace))
                    summaryChip(icon: "fork.knife", label: String(format: "%.1fg/kg", proteinPerKg))
                }
            }
        }
        .padding(16)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppColors.shadowColor, radius: 8, x: 0, y: 2)
    }

    // MARK: - Reusable sub-views

    @ViewBuilder
    private var activityPicker: some View {
        Picker("Activity", selection: $activityLevel) {
            Text("Sedentary").tag("sedentary")
            Text("Light").tag("light")
            Text("Moderate").tag("moderate")
            Text("Active").tag("active")
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var pacePicker: some View {
        Picker("Pace", selection: $weightLossPace) {
            Text("Maintain").tag(0.0)
            Text("−0.25 kg").tag(0.25)
            Text("−0.5 kg").tag(0.5)
            Text("−0.75 kg").tag(0.75)
            Text("−1 kg").tag(1.0)
        }
        .pickerStyle(.segmented)
        .font(.caption)
    }

    @ViewBuilder
    private func macroChip(value: String, label: String, color: Color) -> some View {
        (Text(value).fontWeight(.bold).foregroundStyle(color)
            + Text(" \(label)").foregroundStyle(Color(.secondaryLabel)))
    }

    @ViewBuilder
    private func summaryChip(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10))
            Text(label).font(.caption).lineLimit(1).minimumScaleFactor(0.7)
        }
        .foregroundStyle(Color(.secondaryLabel))
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(AppColors.background)
        .clipShape(Capsule())
    }

    // MARK: - Helpers

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
