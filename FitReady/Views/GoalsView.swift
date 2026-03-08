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

    @State private var paceSliderValue:    Double = 0.5
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

    private var effectiveWeight: Double? {
        if useManualWeight { return manualWeightKg > 0 ? manualWeightKg : nil }
        return healthKit.currentWeightKg ?? (manualWeightKg > 0 ? manualWeightKg : nil)
    }

    private var paceApplies: Bool { primaryGoal == "lose" || primaryGoal == "gain" }

    private var currentPaceLabel: String {
        switch paceSliderValue {
        case 0.25: return "Relaxed"
        case 0.75: return "Aggressive"
        default:   return "Moderate"
        }
    }

    private var currentPaceDesc: String {
        switch paceSliderValue {
        case 0.25: return "~0.25 kg/week — gentle progress, easier to stick with"
        case 0.75: return "~0.75 kg/week — faster results, higher discipline needed"
        default:   return "~0.5 kg/week — the sweet spot for most people"
        }
    }

    private var weeksToGoal: Double? {
        guard let weight = effectiveWeight, weight > 0,
              goalWeightKg > 0,
              primaryGoal == "lose" || primaryGoal == "gain" else { return nil }
        let diff = abs(weight - goalWeightKg)
        guard paceSliderValue > 0 else { return nil }
        return diff / paceSliderValue
    }

    private var dailyDeficit: Int {
        switch primaryGoal {
        case "lose":  return  Int(paceSliderValue * 7700 / 7)
        case "gain":  return -Int(paceSliderValue * 7700 / 7)
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

                    // ── Your targets (top) ────────────────────────────
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
                                    .foregroundStyle(AppColors.textPrimary)
                                Spacer()
                                Text(targetDateLabel)
                                    .font(DS.Typography.body())
                                    .foregroundStyle(
                                        (targetDateChosen || goalTargetDateTS > 0)
                                            ? AppColors.textPrimary : AppColors.textMuted
                                    )
                                Image(systemName: showTargetDatePicker ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppColors.textMuted)
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

                    // ── Primary goal ──────────────────────────────────
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

                            VStack(spacing: DS.Spacing.sm) {
                                Slider(value: $paceSliderValue, in: 0.25...0.75, step: 0.25)
                                    .tint(AppColors.accent)
                                    .padding(.horizontal, DS.Spacing.lg)
                                    .onChange(of: paceSliderValue) { _, _ in
                                        Haptics.impact(.light)
                                    }

                                HStack {
                                    Text("Relaxed")
                                        .font(.caption)
                                        .foregroundStyle(AppColors.textMuted)
                                    Spacer()
                                    Text("Aggressive")
                                        .font(.caption)
                                        .foregroundStyle(AppColors.textMuted)
                                }
                                .padding(.horizontal, DS.Spacing.lg)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(currentPaceLabel)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(AppColors.textPrimary)
                                    Text(currentPaceDesc)
                                        .font(DS.Typography.caption())
                                        .foregroundStyle(AppColors.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, DS.Spacing.lg)
                                .padding(.bottom, DS.Spacing.xs)
                            }
                            .padding(.top, DS.Spacing.xs)

                            Text("A more aggressive pace may reduce muscle retention.")
                                .font(DS.Typography.caption())
                                .foregroundStyle(AppColors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, DS.Spacing.lg)
                                .padding(.bottom, DS.Spacing.md)
                        }
                    }

                    // ── Missing stats warning ─────────────────────────
                    if missingStats {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(AppColors.amberText)
                            Text("Add your weight, height, and age in Personal first.")
                                .font(DS.Typography.caption())
                                .foregroundStyle(AppColors.textSecondary)
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
                        .foregroundStyle(AppColors.textOnBrand)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                        .background(AppColors.brandPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Corner.button))
                    }

                    Spacer(minLength: DS.Spacing.xl)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)
            }
            .scrollDismissesKeyboard(.immediately)
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
            syncPaceSlider()
            loadGoalFields()
        }
        .sheet(isPresented: $showingPlanSplash) {
            if let targets = pendingTargets {
                PlanSplashView(
                    targets:           targets,
                    goalLabel:         goals.first { $0.key == primaryGoal }?.label ?? primaryGoal,
                    weeksToGoal:       weeksToGoal,
                    dailyDeficit:      dailyDeficit,
                    goalWeightDisplay: goalWeightDisplayString,
                    bodyFatGoal:       goalBodyFatPct > 0 ? goalBodyFatPct : nil,
                    targetDate:        (targetDateChosen || goalTargetDateTS > 0) ? targetDate : nil,
                    coaching:          coaching,
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
                    .foregroundStyle(AppColors.textPrimary)
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
        let effectivePace: Double
        switch primaryGoal {
        case "lose":  effectivePace =  paceSliderValue
        case "gain":  effectivePace = -paceSliderValue
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

        // Show splash — always animate for ≥ 3 seconds
        coaching = nil
        isLoadingCoaching = true
        showingPlanSplash = true

        let capturedStart  = Date()
        let capturedKcal   = pendingTargets?.kcal ?? 0
        let capturedWeight = weight
        let capturedGoalWt = goalWeightKg > 0 ? goalWeightKg : nil
        let capturedWeeks  = weeksToGoal
        let capturedGoal   = primaryGoal

        Task {
            let minDelay = 3.0
            if !apiKey.isEmpty {
                do {
                    let result = try await AnthropicService.generatePlanCoaching(
                        goal:            capturedGoal,
                        currentWeightKg: capturedWeight,
                        goalWeightKg:    capturedGoalWt,
                        weeksToGoal:     capturedWeeks,
                        dailyKcal:       capturedKcal,
                        apiKey:          apiKey
                    )
                    let elapsed = Date().timeIntervalSince(capturedStart)
                    let remaining = max(0, minDelay - elapsed)
                    if remaining > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
                    }
                    coaching = result
                } catch {
                    let elapsed = Date().timeIntervalSince(capturedStart)
                    let remaining = max(0, minDelay - elapsed)
                    if remaining > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
                    }
                    coaching = fallbackCoaching
                }
            } else {
                try? await Task.sleep(nanoseconds: UInt64(minDelay * 1_000_000_000))
                coaching = fallbackCoaching
            }
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

    private func syncPaceSlider() {
        let pace = abs(weightLossPace)
        if pace > 0 {
            let rounded = (pace / 0.25).rounded() * 0.25
            paceSliderValue = min(max(rounded, 0.25), 0.75)
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
            .foregroundStyle(AppColors.textSecondary)
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
                .foregroundStyle(AppColors.textSecondary)
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

    @State private var thinkingPhase: Int = 0

    private let thinkingPhrases = [
        "Analysing your goals…",
        "Crunching the numbers…",
        "Crafting your plan…",
        "Almost there…"
    ]

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
                        .foregroundStyle(AppColors.textOnBrand)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.brandPrimary)
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
                .foregroundStyle(AppColors.textSecondary)

            Group {
                if isLoadingCoaching {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColors.metricInactive)
                        .frame(height: 28, alignment: .center)
                        .padding(.horizontal, 40)
                } else {
                    Text(coaching?.headline ?? "Your plan is ready.")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppColors.textPrimary)
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
                .foregroundStyle(AppColors.textSecondary)

            HStack(spacing: 0) {
                macroCell(value: "\(targets.kcal)",      label: "kcal",    color: AppColors.dataCalories)
                Divider().frame(height: 36)
                macroCell(value: "\(targets.proteinG)g", label: "protein", color: AppColors.dataProtein)
                Divider().frame(height: 36)
                macroCell(value: "\(targets.fatG)g",     label: "fat",     color: AppColors.dataFat)
                Divider().frame(height: 36)
                macroCell(value: "\(targets.carbsG)g",   label: "carbs",   color: AppColors.dataCarbs)
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
                .foregroundStyle(AppColors.textSecondary)

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
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                Text(realismLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.textOnBrand)
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
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppColors.accent)
                .symbolEffect(.pulse)

            Text(thinkingPhrases[thinkingPhase % thinkingPhrases.count])
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .id(thinkingPhase)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.easeInOut(duration: 0.35), value: thinkingPhase)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppColors.shadowColor, radius: 6, x: 0, y: 2)
        .task(id: isLoadingCoaching) {
            guard isLoadingCoaching else { return }
            while !Task.isCancelled && isLoadingCoaching {
                try? await Task.sleep(nanoseconds: 900_000_000)
                guard isLoadingCoaching, !Task.isCancelled else { return }
                withAnimation { thinkingPhase += 1 }
            }
        }
    }

    private func tipsCard(_ tips: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HOW TO WIN")
                .font(.system(size: 11, weight: .semibold))
                .kerning(0.5)
                .foregroundStyle(AppColors.textSecondary)

            ForEach(Array(tips.enumerated()), id: \.offset) { _, tip in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.greenText)
                        .padding(.top, 2)
                    Text(tip)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textPrimary)
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
                .foregroundStyle(AppColors.textSecondary)
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
                .foregroundStyle(AppColors.textPrimary)
        }
    }
}
