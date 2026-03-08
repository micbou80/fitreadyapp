import SwiftUI

/// Evening check-out flow (triggered after 9 pm, once per day).
///
/// Steps:
///   0  — Energy rating 1–5
///   1  — Mood picker (auto-advances)
///   2  — Day signals reveal + personalised affirmation + celebration
///
/// Celebration tiers (fires on step 2 appear):
///   3 pillars hit → confetti + strong haptic series
///   2 pillars hit → high-five icon + success haptic
///   1 pillar  hit → medium haptic
///   0 pillars hit → light haptic + encouraging copy
struct EveningCheckOutView: View {

    @EnvironmentObject private var healthKit: HealthKitManager

    @AppStorage("profileName")         private var profileName:      String = ""
    @AppStorage("weeklyPlan")          private var weeklyPlan:       String = "W,L,W,L,W,R,R"
    @AppStorage("checkOutsJSON")       private var checkOutsJSON:    String = "[]"
    @AppStorage("lastCheckOutDate")    private var lastCheckOutDate: String = ""
    @AppStorage("lastCheckOutMessage") private var lastCheckOutMessage: String = ""

    @AppStorage("proteinPerKg")    private var proteinPerKg:   Double = 1.8
    @AppStorage("manualWeightKg")  private var manualWeight:   Double = 0
    @AppStorage("useManualWeight") private var useManualWeight: Bool  = false
    @AppStorage("mealsJSON")       private var mealsJSON:       String = "[]"

    @State private var step:          Int    = 0
    @State private var energyRating:  Int    = 0
    @State private var mood:          String = ""

    // Celebration state
    @State private var showConfetti:   Bool    = false
    @State private var showHighFive:   Bool    = false
    @State private var highFiveScale:  CGFloat = 0.1
    @State private var highFiveOpacity: Double = 0

    var onDismiss: () -> Void

    // MARK: - Body

    var body: some View {
        ZStack {
            DS.Background.page.ignoresSafeArea()

            VStack(spacing: 0) {
                stepDots
                    .padding(.top, DS.Spacing.xl)

                switch step {
                case 0:
                    energyStep
                        .transition(.asymmetric(insertion: .move(edge: .trailing),
                                                removal:   .move(edge: .leading)))
                case 1:
                    moodStep
                        .transition(.asymmetric(insertion: .move(edge: .trailing),
                                                removal:   .move(edge: .leading)))
                case 2:
                    affirmationStep
                        .transition(.asymmetric(insertion: .move(edge: .trailing),
                                                removal:   .move(edge: .leading)))
                default:
                    EmptyView()
                }
            }

            // — Confetti (all 3 pillars) —
            if showConfetti {
                ConfettiView()
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            // — High five (2 pillars) —
            if showHighFive {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 88))
                    .foregroundStyle(AppColors.accent.opacity(0.90))
                    .scaleEffect(highFiveScale)
                    .opacity(highFiveOpacity)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: step)
    }

    // MARK: - Step dots

    private var stepDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(i <= step ? AppColors.accent : AppColors.metricInactive)
                    .frame(width: 6, height: 6)
            }
        }
    }

    // MARK: - Step 0: Energy

    private struct EnergyOption: Identifiable {
        let id      = UUID()
        let rating: Int
        let label:  String
    }

    private let energyOptions: [EnergyOption] = [
        EnergyOption(rating: 1, label: "Very low"),
        EnergyOption(rating: 2, label: "Low"),
        EnergyOption(rating: 3, label: "Okay"),
        EnergyOption(rating: 4, label: "Good"),
        EnergyOption(rating: 5, label: "High"),
    ]

    private var energyStep: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                Text("How was your\nenergy today?")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .lineSpacing(4)
                VStack(spacing: DS.Spacing.sm) {
                    ForEach(energyOptions) { opt in energyRow(opt) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.xl)
            Spacer()
            ctaButton("Next", enabled: energyRating > 0) { advance() }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xl)
        }
    }

    @ViewBuilder
    private func energyRow(_ opt: EnergyOption) -> some View {
        let selected = energyRating == opt.rating
        Button {
            energyRating = opt.rating
            Haptics.impact(.light)
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Text("\(opt.rating)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(selected ? AppColors.accent : AppColors.textMuted)
                    .frame(width: 28, alignment: .center)
                Text(opt.label)
                    .font(.system(size: 17, weight: selected ? .semibold : .regular))
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.accent)
                }
            }
            .foregroundStyle(selected ? AppColors.accent : AppColors.textPrimary)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(selected ? AppColors.accent.opacity(0.10) : DS.Background.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Corner.button))
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.2, dampingFraction: 0.75), value: selected)
    }

    // MARK: - Step 1: Mood

    private struct MoodOption: Identifiable {
        let id    = UUID()
        let key:   String
        let label: String
    }

    private let moodOptions: [MoodOption] = [
        MoodOption(key: "strong", label: "Strong"),
        MoodOption(key: "good",   label: "Good"),
        MoodOption(key: "okay",   label: "Okay"),
        MoodOption(key: "tired",  label: "Tired"),
        MoodOption(key: "rough",  label: "Rough"),
    ]

    private var moodStep: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                Text("How do you feel\nright now?")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .lineSpacing(4)
                VStack(spacing: DS.Spacing.sm) {
                    ForEach(moodOptions) { opt in moodRow(opt) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.xl)
            Spacer()
        }
    }

    @ViewBuilder
    private func moodRow(_ opt: MoodOption) -> some View {
        let selected = mood == opt.key
        Button {
            mood = opt.key
            Haptics.impact(.light)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation { step = 2 }
            }
        } label: {
            HStack {
                Text(opt.label)
                    .font(.system(size: 17, weight: selected ? .semibold : .regular))
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.accent)
                }
            }
            .foregroundStyle(selected ? AppColors.accent : AppColors.textPrimary)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(selected ? AppColors.accent.opacity(0.10) : DS.Background.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Corner.button))
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.2, dampingFraction: 0.75), value: selected)
    }

    // MARK: - Step 2: Affirmation + celebration

    private var affirmationStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DS.Spacing.xl) {
                Spacer(minLength: DS.Spacing.xl)

                // Personalised affirmation
                VStack(spacing: DS.Spacing.sm) {
                    Text(celebrationTitle)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                    Text(celebrationBody)
                        .font(.system(size: 17))
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(.horizontal, DS.Spacing.xl)

                // Caloric balance pill
                if kcalConsumed > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(caloricBalanceColor)
                        Text(caloricBalanceText)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(caloricBalanceColor)
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(caloricBalanceColor.opacity(0.10))
                    .clipShape(Capsule())
                }

                // Day signals card
                VStack(spacing: 0) {
                    signalRow(icon: "figure.walk",   color: AppColors.greenText,
                              label: "Steps",    value: stepsText,      hit: stepsHit)
                    Divider().padding(.leading, 52)
                    signalRow(icon: "fork.knife",    color: AppColors.amberText,
                              label: "Calories", value: kcalText,       hit: kcalHit)
                    Divider().padding(.leading, 52)
                    signalRow(icon: "🥚", color: AppColors.accent,
                              label: "Protein",  value: proteinText,    hit: proteinHit)
                    Divider().padding(.leading, 52)
                    signalRow(icon: "bolt.fill",     color: AppColors.warning,
                              label: "Active",   value: activeKcalText, hit: activeHit)
                }
                .background(DS.Background.card)
                .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
                .shadow(color: DS.Shadow.color, radius: DS.Shadow.radius, x: 0, y: DS.Shadow.y)
                .padding(.horizontal, DS.Spacing.xl)

                // Tomorrow signal
                VStack(spacing: 4) {
                    Text("Tomorrow · \(tomorrowTypeLabel)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.textMuted)
                    Text(tomorrowCopy)
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, DS.Spacing.xl)

                ctaButton("Done", enabled: true) { saveAndDismiss() }
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.bottom, DS.Spacing.xl)
            }
        }
        .onAppear { triggerCelebration() }
    }

    @ViewBuilder
    private func signalRow(icon: String, color: Color, label: String, value: String, hit: Bool) -> some View {
        HStack(spacing: DS.Spacing.md) {
            let isEmoji = icon.unicodeScalars.first.map { $0.value > 127 } ?? false
            Group {
                if isEmoji {
                    Text(icon).font(.system(size: 16))
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(color)
                }
            }
            .frame(width: 20)
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
            Image(systemName: hit ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(hit ? AppColors.greenText : AppColors.border)
        }
        .padding(DS.Spacing.md)
    }

    // MARK: - Celebration

    /// Number of body-composition pillars hit (Steps / Protein / Active).
    private var pillarsHit: Int {
        [stepsHit, proteinHit, activeHit].filter { $0 }.count
    }

    private func triggerCelebration() {
        switch pillarsHit {
        case 3:
            // Decrescendo haptic series (~1.5 s) + full confetti
            Haptics.notification(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) { Haptics.impact(.heavy) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) { Haptics.impact(.heavy) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { Haptics.impact(.medium) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.90) { Haptics.impact(.medium) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) { Haptics.impact(.light) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) { Haptics.impact(.light) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeIn(duration: 0.2)) { showConfetti = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
                withAnimation(.easeOut(duration: 0.8)) { showConfetti = false }
            }

        case 2:
            // Lighter haptic series (~1.5 s) + high-five icon bounce
            Haptics.notification(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) { Haptics.impact(.medium) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.60) { Haptics.impact(.medium) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) { Haptics.impact(.light) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.30) { Haptics.impact(.light) }
            showHighFive   = true
            highFiveScale  = 0.1
            highFiveOpacity = 0
            withAnimation(.spring(response: 0.38, dampingFraction: 0.55)) {
                highFiveScale   = 1.0
                highFiveOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.easeOut(duration: 0.45)) {
                    highFiveOpacity = 0
                    highFiveScale   = 0.85
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showHighFive = false }
            }

        case 1:
            Haptics.impact(.medium)

        default:
            // Still warm — light haptic
            Haptics.impact(.light)
        }
    }

    // MARK: - Personalised affirmation copy

    private var celebrationTitle: String {
        let n = profileName.isEmpty ? "" : "\(profileName), "
        switch pillarsHit {
        case 3: return "\(n)all signals green."
        case 2: return "\(n)two of three."
        case 1: return "Signal registered."
        default: return "Rest is part of the process."
        }
    }

    private var celebrationBody: String {
        switch pillarsHit {
        case 3:
            return "You put in the work today. \(stepsText), protein dialled, active energy tracked. Days like this are what compound."
        case 2:
            if !stepsHit   { return "You nailed nutrition and activity today. A longer walk tomorrow closes the loop." }
            if !proteinHit { return "You moved \(stepsText) today. Protein is tomorrow's priority." }
            return "You hit \(stepsText) and protein today. One more signal to close the week strong."
        case 1:
            if stepsHit   { return "You put in \(stepsText) today. Movement is the foundation — keep building." }
            if proteinHit { return "Fuel is set. Your body has what it needs to recover tonight." }
            return "You got active energy in today. Every session compounds."
        default:
            return "You showed up and checked in — that already puts you ahead. Rest well. Tomorrow is a fresh start."
        }
    }

    // MARK: - Caloric balance

    private var caloricBalance: Int { kcalTarget - kcalConsumed }

    private var caloricBalanceText: String {
        let abs = Swift.abs(caloricBalance)
        let fmt = NumberFormatter(); fmt.numberStyle = .decimal
        let n = fmt.string(from: NSNumber(value: abs)) ?? "\(abs)"
        if Swift.abs(caloricBalance) <= 50 { return "On target" }
        return caloricBalance > 0 ? "−\(n) kcal under goal" : "+\(n) kcal over goal"
    }

    private var caloricBalanceColor: Color {
        guard kcalConsumed > 0 else { return AppColors.textSecondary }
        // Deficit or on-target = green; meaningful surplus = amber
        return caloricBalance >= -50 ? AppColors.greenText : AppColors.amberText
    }

    // MARK: - CTA button

    private func ctaButton(_ label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppColors.textOnBrand)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
                .background(AppColors.brandPrimary.opacity(enabled ? 1 : 0.4))
                .clipShape(RoundedRectangle(cornerRadius: DS.Corner.button))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: - Navigation

    private func advance() { withAnimation { step += 1 } }

    // MARK: - Health data (HealthKit → in-app meals → 0)

    private var steps:      Int { Int(healthKit.todaySteps      ?? 0) }
    private var activeKcal: Int { Int(healthKit.todayActiveKcal ?? 0) }

    private var kcalConsumed: Int {
        if let hk = healthKit.todayKcal      { return Int(hk) }
        return Int(todayMealTotals?.kcal     ?? 0)
    }
    private var proteinConsumed: Int {
        if let hk = healthKit.todayProteinG  { return Int(hk) }
        return Int(todayMealTotals?.protein  ?? 0)
    }

    private var todayMealTotals: (kcal: Double, protein: Double)? {
        guard let meals = try? JSONDecoder().decode([MealEntry].self, from: Data(mealsJSON.utf8)) else { return nil }
        let today = meals.filter { $0.date == DailyCheckOut.todayKey() }
        guard !today.isEmpty else { return nil }
        return (kcal: today.reduce(0) { $0 + $1.kcal }, protein: today.reduce(0) { $0 + $1.proteinG })
    }

    // MARK: - Targets

    private var stepGoal:     Int { 10_000 }
    private var kcalTarget:   Int { 2_000 }
    private var proteinTarget: Int {
        let wt = useManualWeight ? manualWeight : 70.0
        return max(100, Int(wt * proteinPerKg))
    }

    // MARK: - Hit thresholds

    private var stepsHit:   Bool { steps >= stepGoal }
    private var kcalHit:    Bool { kcalConsumed > 0 && kcalConsumed >= Int(Double(kcalTarget) * 0.90) }
    private var proteinHit: Bool { proteinConsumed >= Int(Double(proteinTarget) * 0.90) }
    private var activeHit:  Bool { activeKcal >= 300 }

    // MARK: - Formatted values

    private var stepsText: String {
        let fmt = NumberFormatter(); fmt.numberStyle = .decimal
        return (fmt.string(from: NSNumber(value: steps)) ?? "\(steps)") + " steps"
    }
    private var kcalText: String {
        guard kcalConsumed > 0 else { return "—" }
        let fmt = NumberFormatter(); fmt.numberStyle = .decimal
        return (fmt.string(from: NSNumber(value: kcalConsumed)) ?? "\(kcalConsumed)") + " kcal"
    }
    private var proteinText:    String { proteinConsumed > 0 ? "\(proteinConsumed) / \(proteinTarget)g" : "—" }
    private var activeKcalText: String {
        guard activeKcal > 0 else { return "—" }
        let fmt = NumberFormatter(); fmt.numberStyle = .decimal
        return (fmt.string(from: NSNumber(value: activeKcal)) ?? "\(activeKcal)") + " kcal"
    }

    // MARK: - Tomorrow

    private var tomorrowLetter: String {
        let parts = weeklyPlan.components(separatedBy: ",")
        guard parts.count == 7 else { return "W" }
        let todayIdx = (Calendar.current.component(.weekday, from: Date()) - 2 + 7) % 7
        return parts[(todayIdx + 1) % 7]
    }
    private var tomorrowTypeLabel: String {
        switch tomorrowLetter { case "W": return "Train day"; case "L": return "Light session"; default: return "Rest day" }
    }
    private var tomorrowCopy: String {
        switch tomorrowLetter {
        case "W": return "Sleep deep — strength is built at night."
        case "L": return "Easy tomorrow. Keep the rhythm going."
        default:  return "Recovery is part of the plan. Sleep well."
        }
    }

    // MARK: - Check-out object

    private var builtCheckOut: DailyCheckOut {
        DailyCheckOut(date: DailyCheckOut.todayKey(), energyRating: energyRating, mood: mood,
                      steps: steps, kcalConsumed: kcalConsumed, kcalTarget: kcalTarget,
                      proteinConsumed: proteinConsumed, proteinTarget: proteinTarget, activeKcal: activeKcal)
    }

    // MARK: - Save

    private func saveAndDismiss() {
        let entry = builtCheckOut
        var checkOuts = DailyCheckOut.load(from: checkOutsJSON)
        checkOuts.removeAll { $0.date == entry.date }
        checkOuts.append(entry)
        checkOuts = Array(checkOuts.suffix(30))
        if let data = try? JSONEncoder().encode(checkOuts),
           let json  = String(data: data, encoding: .utf8) { checkOutsJSON = json }
        lastCheckOutDate    = entry.date
        lastCheckOutMessage = entry.affirmationTitle
        onDismiss()
    }
}

// MARK: - Confetti (Canvas + TimelineView, file-private)

private struct ConfettiView: View {

    private struct Piece {
        let startX: CGFloat   // 0…1 of screen width
        let speed:  CGFloat   // screen heights per second
        let wobble: CGFloat   // horizontal oscillation frequency
        let phase:  CGFloat   // wobble phase offset
        let w:      CGFloat
        let h:      CGFloat
        let color:  Color
        let delay:  Double    // seconds before this piece begins falling

        private static let palette: [Color] = [
            AppColors.brandPrimary, AppColors.warning, AppColors.danger,
            AppColors.info, AppColors.brandDark, AppColors.textSecondary,
            AppColors.warning, AppColors.brandPrimary, AppColors.info,
        ]
        init() {
            startX = .random(in: 0.03...0.97)
            speed  = .random(in: 0.12...0.28)
            wobble = .random(in: 1.0...3.5)
            phase  = .random(in: 0...(2 * .pi))
            w      = .random(in: 5...11)
            h      = .random(in: 8...15)
            color  = Self.palette.randomElement()!
            delay  = .random(in: 0...0.80)
        }
    }

    private let pieces: [Piece] = (0..<90).map { _ in Piece() }
    private let startTime = Date()

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSince(startTime)
                for p in pieces {
                    let elapsed = t - p.delay
                    guard elapsed > 0 else { continue }
                    let y = CGFloat(elapsed) * p.speed * size.height - 20
                    guard y < size.height + 20 else { continue }
                    let x = p.startX * size.width + sin(CGFloat(elapsed) * p.wobble + p.phase) * 22
                    let fadeStart: Double = 3.8
                    let opacity = elapsed < fadeStart ? 1.0 : max(0, 1 - (elapsed - fadeStart) / 1.5)
                    ctx.opacity = opacity
                    var path = Path()
                    path.addRoundedRect(
                        in:         CGRect(x: x - p.w/2, y: y, width: p.w, height: p.h),
                        cornerSize: CGSize(width: 2, height: 2)
                    )
                    ctx.fill(path, with: .color(p.color))
                }
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    EveningCheckOutView { }
        .environmentObject(HealthKitManager())
}
