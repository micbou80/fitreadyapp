import SwiftUI

/// Goals: primary goal, pace, targets (weight / body fat / date), and Personalize My Plan.
struct GoalsView: View {

    @EnvironmentObject private var healthKit: HealthKitManager

    @AppStorage("primaryGoal")      private var primaryGoal:      String = "lose"
    @AppStorage("weightLossPace")   private var weightLossPace:   Double = 0.5
    @AppStorage("proteinPerKg")     private var proteinPerKg:     Double = 1.8
    @AppStorage("fatFloorPct")      private var fatFloorPct:      Double = 25
    @AppStorage("activityLevel")    private var activityLevel:    String = "moderate"
    @AppStorage("heightCm")         private var heightCm:         Double = 0
    @AppStorage("ageYears")         private var ageYears:         Int    = 0
    @AppStorage("biologicalSex")    private var biologicalSex:    String = ""
    @AppStorage("manualWeightKg")   private var manualWeightKg:   Double = 0
    @AppStorage("useManualWeight")  private var useManualWeight:  Bool   = false
    @AppStorage("goalWeightKg")     private var goalWeightKg:     Double = 0
    @AppStorage("goalBodyFatPct")   private var goalBodyFatPct:   Double = 0
    @AppStorage("goalTargetDateTS") private var goalTargetDateTS: Double = 0
    @AppStorage("useImperial")      private var useImperial:      Bool   = false
    @AppStorage("anthropicAPIKey")  private var apiKey:           String = ""

    @State private var selectedPaceKey:    String = "moderate"
    @State private var goalWeightText:     String = ""
    @State private var goalFatPctText:     String = ""
    @State private var targetDate:         Date   = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @State private var targetDateChosen:   Bool   = false
    @State private var showTargetDatePicker = false
    @State private var missingStats        = false
    @State private var pendingTargets:     MacroTargets? = nil
    @State private var coaching:           PlanCoaching? = nil
    @State private var isLoadingCoaching   = false
    @State private var showingPlanSplash   = false

    @FocusState private var focusedField: GoalField?
    private enum GoalField { case weight, fatPct }

    // MARK: - Data

    private let goals: [(key: String, label: String, icon: String, color: Color)] = [
        ("lose",     "Lose weight",  "arrow.down.circle.fill", AppColors.greenText),
        ("maintain", "Maintain",     "equal.circle.fill",      AppColors.accent),
        ("gain",     "Gain weight",  "arrow.up.circle.fill",   AppColors.amberText),
        ("muscle",   "Build muscle", "dumbbell.fill",           AppColors.redText),
    ]

    private let paces: [(key: String, label: String, desc: String, value: Double)] = [
        ("relaxed",    "Relaxed",    "~0.25 kg/week — gentle progress, easier to stick with",   0.25),
        ("moderate",   "Moderate",   "~0.5 kg/week — the sweet spot for most people",            0.50),
        ("aggressive", "Aggressive", "~0.75 kg/week — faster results, higher discipline needed", 0.75),
    ]

    private var effectiveWeight: Double? {
        if useManualWeight { return manualWeightKg > 0 ? manualWeightKg : nil }
        return healthKit.currentWeightKg ?? (manualWeightKg > 0 ? manualWeightKg : nil)
    }

    private var paceApplies: Bool { primaryGoal == "lose" || primaryGoal == "gain" }

    private var weeksToGoal: Double? {
        guard let weight = effectiveWeight, weight > 0,
              goalWeightKg > 0,
              primaryGoal == "lose" || primaryGoal == "gain" else { return nil }
        let diff = abs(weight - goalWeightKg)
        let pace = paces.first { $0.key == selectedPaceKey }?.value ?? 0.5
        guard pace > 0 else { return nil }
        return diff / pace
    }

    private var dailyDeficit: Int {
        let pace = paces.first { $0.key == selectedPaceKey }?.value ?? 0.5
        switch primaryGoal {
        case "lose":  return  Int(pace * 7700 / 7)
        case "gain":  return -Int(pace * 7700 / 7)
        default:      return  0
        }
    }

    private var goalWeightLabel: String {
        useImperial ? "Goal weight (lbs)" : "Goal weight (kg)"
    }

    private var goalWeightPlaceholder: String {
        useImperial ? "165" : "75"
    }

    private var targetDateLabel: String {
        guard targetDateChosen || goalTargetDateTS > 0 else { return "Optional" }
        return targetDate.formatted(.dateTime.month(.abbreviated).day().year())
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            DS.Background.page.ignoresSafeArea()
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {

                    // ── Primary goal ─────────────────────────────────
                    settingsCard {
                        sectionLabel("Primary Goal")
                        VStack(spacing: 0) {
                            ForEach(Array(goals.enumerated()), id: \.element.key) { idx, goal in
                                if idx > 0 { Divider().padding(.leading, 52) }
                                goalRow(goal)
                            }
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.bottom, DS.Spacing.md)
                    }

                    // ── Pace (lose / gain only) ───────────────────────
                    if paceApplies {
                        settingsCard {
                            sectionLabel("Weekly Pace")
                            VStack(spacing: 0) {
                                ForEach(Array(paces.enumerated()), id: \.element.key) { idx, pace in
                                    if idx > 0 { Divider().padding(.leading, 52) }
                                    paceRow(pace)
                                }
                            }
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.bottom, DS.Spacing.sm)

                            Text("A more aggressive pace may reduce muscle retention.")
                                .font(DS.Typography.caption())
                                .foregroundStyle(Color(.secondaryLabel))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, DS.Spacing.lg)
                                .padding(.bottom, DS.Spacing.md)
                        }
                    }

                    // ── Your targets ─────────────────────────────────
                    settingsCard {
                        sectionLabel("Your Targets")

                        settingRow(
                            icon: "flag.fill",
                            iconColor: AppColors.accent,
                            label: goalWeightLabel
                        ) {
                            TextField(goalWeightPlaceholder, text: $goalWeightText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .focused($focusedField, equals: .weight)
                                .frame(width: 80)
                        }

                        Divider().padding(.leading, 52)

                        settingRow(
                            icon: "percent",
                            iconColor: AppColors.amberText,
                            label: "Body fat goal (%)"
                        ) {
                            TextField("20", text: $goalFatPctText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .focused($focusedField, equals: .fatPct)
                                .frame(width: 60)
                        }

                        Divider().padding(.leading, 52)

                        // Target date row
                        Button {
                            targetDateChosen = true
                            showTargetDatePicker.toggle()
                            focusedField = nil
                        } label: {
                            HStack(spacing: DS.Spacing.md) {
                                Image(systemName: "calendar.badge.checkmark")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(AppColors.greenText)
                                    .frame(width: 28, height: 28)
                                    .background(AppColors.greenText.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                Text("Target date")
                                    .font(DS.Typography.body())
                                    .foregroundStyle(Color(.label))
                                Spacer()
                                Text(targetDateLabel)
                                    .font(DS.Typography.body())
                                    .foregroundStyle(
                                        (targetDateChosen || goalTargetDateTS > 0)
                                            ? Color(.label) : Color(.tertiaryLabel)
                                    )
                                Image(systemName: showTargetDatePicker ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color(.tertiaryLabel))
                            }
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.vertical, DS.Spacing.md)
                        }
                        .buttonStyle(.plain)

                        if showTargetDatePicker {
                            DatePicker(
                                "",
                                selection: $targetDate,
                                in: Date()...,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .tint(AppColors.accent)
                            .padding(.horizontal, DS.Spacing.md)
                        }
                    }

                    // ── Missing stats warning ─────────────────────────
                    if missingStats {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(AppColors.amberText)
                            Text("Add your weight, height, and age in Personal first.")
                                .font(DS.Typography.caption())
                                .foregroundStyle(Color(.secondaryLabel))
                        }
                        .padding(DS.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.amberSoft)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Corner.chip))
                    }

                    // ── Personalize button ────────────────────────────
                    Button(action: personalizeMyPlan) {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "sparkles")
                            Text("Personalize My Plan")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                        .background(AppColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Corner.button))
                    }

                    Spacer(minLength: DS.Spacing.xl)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)
            }
            .simultaneousGesture(TapGesture().onEnded { focusedField = nil })
        }
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .onAppear {
            syncPaceKey()
            loadGoalFields()
        }
        .sheet(isPresented: $showingPlanSplash) {
            if let targets = pendingTargets {
                PlanSplashView(
                    targets:          targets,
                    goalLabel:        goals.first { $0.key == primaryGoal }?.label ?? primaryGoal,
                    weeksToGoal:      weeksToGoal,
                    dailyDeficit:     dailyDeficit,
                    goalWeightDisplay: goalWeightDisplayString,
                    bodyFatGoal:      goalBodyFatPct > 0 ? goalBodyFatPct : nil,
                    targetDate:       (targetDateChosen || goalTargetDateTS > 0) ? targetDate : nil,
                    coaching:         coaching,
                    isLoadingCoaching: isLoadingCoaching,
                    onAdjust: { showingPlanSplash = false },
                    onLetsGo: {
                        showingPlanSplash = false
                        NotificationCenter.default.post(name: .switchToTodayTab, object: nil)
                    }
                )
            }
        }
    }

    // MARK: - Row builders

    @ViewBuilder
    private func goalRow(_ goal: (key: String, label: String, icon: String, color: Color)) -> some View {
        Button {
            primaryGoal = goal.key
            Haptics.impact(.light)
            missingStats = false
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: goal.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(goal.color)
                    .frame(width: 36, height: 36)
                    .background(goal.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(goal.label)
                    .font(DS.Typography.body())
                    .foregroundStyle(Color(.label))
                Spacer()
                if primaryGoal == goal.key {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.accent)
                }
            }
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func paceRow(_ pace: (key: String, label: String, desc: String, value: Double)) -> some View {
        Button {
            selectedPaceKey = pace.key
            Haptics.impact(.light)
        } label: {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pace.label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(.label))
                    Text(pace.desc)
                        .font(DS.Typography.caption())
                        .foregroundStyle(Color(.secondaryLabel))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if selectedPaceKey == pace.key {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.accent)
                        .padding(.top, 1)
                }
            }
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Personalize

    private func personalizeMyPlan() {
        missingStats = false
        focusedField = nil

        guard let weight = effectiveWeight, weight > 0,
              heightCm > 0, ageYears > 0 else {
            missingStats = true
            Haptics.notification(.warning)
            return
        }

        // Persist pace
        let paceValue = paces.first { $0.key == selectedPaceKey }?.value ?? 0.5
        let effectivePace: Double
        switch primaryGoal {
        case "lose":  effectivePace =  paceValue
        case "gain":  effectivePace = -paceValue
        default:      effectivePace =  0
        }
        weightLossPace = effectivePace

        // Persist goal targets
        if let gw = Double(goalWeightText.replacingOccurrences(of: ",", with: ".")) {
            goalWeightKg = useImperial ? gw / 2.20462 : gw
        }
        if let fp = Double(goalFatPctText.replacingOccurrences(of: ",", with: ".")) {
            goalBodyFatPct = fp
        }
        if targetDateChosen || goalTargetDateTS > 0 {
            goalTargetDateTS = targetDate.timeIntervalSince1970
        }

        // Compute macro targets
        pendingTargets = MacroEngine.compute(
            weightKg:      weight,
            heightCm:      heightCm,
            ageYears:      ageYears,
            isMale:        biologicalSex == "male",
            activityLevel: activityLevel,
            paceKgPerWeek: effectivePace,
            proteinPerKg:  proteinPerKg,
            fatFloorPct:   fatFloorPct
        )
        guard pendingTargets != nil else { return }

        // Show splash
        coaching = nil
        isLoadingCoaching = !apiKey.isEmpty
        showingPlanSplash = true

        // Fetch coaching (fire-and-forget; updates splash when done)
        if !apiKey.isEmpty {
            let capturedKcal    = pendingTargets?.kcal ?? 0
            let capturedWeight  = weight
            let capturedGoalWt  = goalWeightKg > 0 ? goalWeightKg : nil
            let capturedWeeks   = weeksToGoal
            Task {
                do {
                    coaching = try await AnthropicService.generatePlanCoaching(
                        goal:           primaryGoal,
                        currentWeightKg: capturedWeight,
                        goalWeightKg:   capturedGoalWt,
                        weeksToGoal:    capturedWeeks,
                        dailyKcal:      capturedKcal,
                        apiKey:         apiKey
                    )
                } catch {
                    coaching = fallbackCoaching
                }
                isLoadingCoaching = false
            }
        } else {
            coaching = fallbackCoaching
            isLoadingCoaching = false
        }

        Haptics.notification(.success)
    }

    private var fallbackCoaching: PlanCoaching {
        switch primaryGoal {
        case "lose":
            return PlanCoaching(
                headline: "Consistency is your secret weapon.",
                tips: [
                    "Prioritise protein at every meal to preserve muscle in a deficit.",
                    "Weigh yourself weekly — daily fluctuations are normal noise.",
                    "Quality sleep directly supports fat loss. Protect it."
                ]
            )
        case "gain", "muscle":
            return PlanCoaching(
                headline: "Progress is built one session at a time.",
                tips: [
                    "Hit your calorie surplus consistently — muscle needs fuel.",
                    "Progressive overload in training is what actually drives gains.",
                    "Protein and sleep are the two things you can't skip."
                ]
            )
        default:
            return PlanCoaching(
                headline: "Steady is fast in the long run.",
                tips: [
                    "Focus on habit quality — what you do most days is what matters.",
                    "Strength training preserves muscle and keeps metabolism active.",
                    "A consistent routine beats an intense one you can't sustain."
                ]
            )
        }
    }

    private var goalWeightDisplayString: String? {
        guard goalWeightKg > 0 else { return nil }
        if useImperial {
            return String(format: "%.0f lbs", goalWeightKg * 2.20462)
        }
        return String(format: "%.1f kg", goalWeightKg)
    }

    // MARK: - Load / Sync

    private func loadGoalFields() {
        if goalWeightKg > 0 {
            goalWeightText = useImperial
                ? String(format: "%.0f", goalWeightKg * 2.20462)
                : String(format: "%.1f", goalWeightKg)
        }
        if goalBodyFatPct > 0 {
            goalFatPctText = String(format: "%.1f", goalBodyFatPct)
        }
        if goalTargetDateTS > 0 {
            targetDate = Date(timeIntervalSince1970: goalTargetDateTS)
            targetDateChosen = true
        }
    }

    private func syncPaceKey() {
        switch abs(weightLossPace) {
        case 0.25: selectedPaceKey = "relaxed"
        case 0.75: selectedPaceKey = "aggressive"
        default:   selectedPaceKey = "moderate"
        }
    }

    // MARK: - Layout helpers

    @ViewBuilder
    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(DS.Background.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
            .shadow(color: DS.Shadow.color, radius: DS.Shadow.radius, x: 0, y: DS.Shadow.y)
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color(.secondaryLabel))
            .kerning(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.xs)
    }

    @ViewBuilder
    private func settingRow<Trailing: View>(
        icon: String,
        iconColor: Color,
        label: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Text(label)
                .font(DS.Typography.body())
            Spacer()
            trailing()
                .foregroundStyle(Color(.secondaryLabel))
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }
}

// MARK: - Plan Splash

private struct PlanSplashView: View {

    let targets:           MacroTargets
    let goalLabel:         String
    let weeksToGoal:       Double?
    let dailyDeficit:      Int          // positive = deficit, negative = surplus
    let goalWeightDisplay: String?
    let bodyFatGoal:       Double?
    let targetDate:        Date?
    let coaching:          PlanCoaching?
    let isLoadingCoaching: Bool
    let onAdjust:          () -> Void
    let onLetsGo:          () -> Void

    private var realismLabel: String {
        guard let weeks = weeksToGoal else {
            return dailyDeficit == 0 ? "Balanced" : "Achievable"
        }
        if weeks < 8  { return "Aggressive" }
        if weeks < 16 { return "Ambitious" }
        return "Achievable"
    }

    private var realismColor: Color {
        switch realismLabel {
        case "Aggressive": return AppColors.redText
        case "Ambitious":  return AppColors.amberText
        default:           return AppColors.greenText
        }
    }

    private func weeksDisplay(_ weeks: Double) -> String {
        if weeks < 8 { return "\(Int(weeks.rounded())) weeks" }
        let months = weeks / 4.33
        if months < 2 { return "\(Int(weeks.rounded())) weeks" }
        return String(format: "%.1f months", months)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    macroCard
                    journeyCard
                    if isLoadingCoaching {
                        loadingCard
                    } else if let c = coaching {
                        tipsCard(c.tips)
                    }
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }

            // Pinned bottom buttons
            VStack(spacing: 0) {
                // Subtle gradient fade above buttons
                LinearGradient(
                    colors: [AppColors.background.opacity(0), AppColors.background],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 24)

                HStack(spacing: 12) {
                    Button("Adjust", action: onAdjust)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    Button(action: onLetsGo) {
                        HStack(spacing: 6) {
                            Text("Let's Go!")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .background(AppColors.background)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("YOUR PLAN IS READY")
                .font(.system(size: 11, weight: .semibold))
                .kerning(1)
                .foregroundStyle(Color(.secondaryLabel))

            Group {
                if isLoadingCoaching {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(height: 28, alignment: .center)
                        .padding(.horizontal, 40)
                } else {
                    Text(coaching?.headline ?? "Your plan is ready.")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color(.label))
                }
            }
        }
        .padding(.top, 8)
    }

    private var macroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DAILY TARGETS")
                .font(.system(size: 11, weight: .semibold))
                .kerning(0.5)
                .foregroundStyle(Color(.secondaryLabel))

            HStack(spacing: 0) {
                macroCell(value: "\(targets.kcal)",       label: "kcal",    color: AppColors.dataCalories)
                Divider().frame(height: 36)
                macroCell(value: "\(targets.proteinG)g",  label: "protein", color: AppColors.dataProtein)
                Divider().frame(height: 36)
                macroCell(value: "\(targets.fatG)g",      label: "fat",     color: AppColors.dataFat)
                Divider().frame(height: 36)
                macroCell(value: "\(targets.carbsG)g",    label: "carbs",   color: AppColors.dataCarbs)
            }
        }
        .padding(16)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppColors.shadowColor, radius: 6, x: 0, y: 2)
    }

    private var journeyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THE JOURNEY")
                .font(.system(size: 11, weight: .semibold))
                .kerning(0.5)
                .foregroundStyle(Color(.secondaryLabel))

            if let weeks = weeksToGoal, weeks > 0 {
                journeyRow(icon: "calendar",
                           iconColor: AppColors.accent,
                           text: "~\(weeksDisplay(weeks)) to reach your goal")
            }

            if dailyDeficit != 0 {
                let isDeficit = dailyDeficit > 0
                journeyRow(
                    icon:      isDeficit ? "flame.fill" : "bolt.fill",
                    iconColor: isDeficit ? AppColors.amberBase : AppColors.greenText,
                    text:      "\(abs(dailyDeficit)) kcal \(isDeficit ? "daily deficit" : "daily surplus")"
                )
            }

            if let gw = goalWeightDisplay {
                journeyRow(icon: "flag.fill", iconColor: AppColors.accent, text: "Target weight: \(gw)")
            }

            if let bf = bodyFatGoal {
                journeyRow(icon: "percent", iconColor: AppColors.amberText,
                           text: "Targeting \(String(format: "%.1f", bf))% body fat")
            }

            if let date = targetDate {
                journeyRow(icon: "calendar.badge.checkmark", iconColor: AppColors.greenText,
                           text: "Goal date: \(date.formatted(.dateTime.month(.wide).day().year()))")
            }

            Divider()

            HStack {
                Text("Assessment")
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabel))
                Spacer()
                Text(realismLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(realismColor)
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppColors.shadowColor, radius: 6, x: 0, y: 2)
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView().scaleEffect(0.9)
            Text("Personalising your coaching tips…")
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppColors.shadowColor, radius: 6, x: 0, y: 2)
    }

    private func tipsCard(_ tips: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HOW TO WIN")
                .font(.system(size: 11, weight: .semibold))
                .kerning(0.5)
                .foregroundStyle(Color(.secondaryLabel))

            ForEach(Array(tips.enumerated()), id: \.offset) { _, tip in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.greenText)
                        .padding(.top, 2)
                    Text(tip)
                        .font(.subheadline)
                        .foregroundStyle(Color(.label))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppColors.shadowColor, radius: 6, x: 0, y: 2)
    }

    // MARK: - Helpers

    private func macroCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity)
    }

    private func journeyRow(icon: String, iconColor: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 24, height: 24)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color(.label))
        }
    }
}
