import SwiftUI

/// Goals: primary goal, pace, and a Calculate button that recomputes macro targets.
struct GoalsView: View {

    @EnvironmentObject private var healthKit: HealthKitManager

    @AppStorage("primaryGoal")    private var primaryGoal:    String = "lose"
    @AppStorage("weightLossPace") private var weightLossPace: Double = 0.5
    @AppStorage("proteinPerKg")   private var proteinPerKg:   Double = 1.8
    @AppStorage("fatFloorPct")    private var fatFloorPct:    Double = 25
    @AppStorage("activityLevel")  private var activityLevel:  String = "moderate"
    @AppStorage("heightCm")       private var heightCm:       Double = 0
    @AppStorage("ageYears")       private var ageYears:       Int    = 0
    @AppStorage("biologicalSex")  private var biologicalSex:  String = ""
    @AppStorage("manualWeightKg") private var manualWeightKg: Double = 0
    @AppStorage("useManualWeight") private var useManualWeight: Bool = false

    @State private var selectedPaceKey: String = "moderate"
    @State private var calculated = false
    @State private var result: MacroTargets? = nil
    @State private var missingStats = false

    // MARK: - Data

    private let goals: [(key: String, label: String, icon: String, color: Color)] = [
        ("lose",     "Lose weight",  "arrow.down.circle.fill", Color(hex: "1B7D38")),
        ("maintain", "Maintain",     "equal.circle.fill",       .purple),
        ("gain",     "Gain weight",  "arrow.up.circle.fill",    Color(hex: "B45309")),
        ("muscle",   "Build muscle", "dumbbell.fill",            Color(hex: "C0392B")),
    ]

    private let paces: [(key: String, label: String, desc: String, value: Double)] = [
        ("relaxed",    "Relaxed",    "~0.25 kg/week — gentle progress, easier to stick with", 0.25),
        ("moderate",   "Moderate",   "~0.5 kg/week — the sweet spot for most people",          0.50),
        ("aggressive", "Aggressive", "~0.75 kg/week — faster results, higher discipline needed", 0.75),
    ]

    private var effectiveWeight: Double? {
        if useManualWeight { return manualWeightKg > 0 ? manualWeightKg : nil }
        return healthKit.currentWeightKg ?? (manualWeightKg > 0 ? manualWeightKg : nil)
    }

    private var paceApplies: Bool { primaryGoal == "lose" || primaryGoal == "gain" }

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

                    // ── Missing stats warning ─────────────────────────
                    if missingStats {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color(hex: "B45309"))
                            Text("Add your weight, height, and age in Personal first.")
                                .font(DS.Typography.caption())
                                .foregroundStyle(Color(.secondaryLabel))
                        }
                        .padding(DS.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: "FFF4E5"))
                        .clipShape(RoundedRectangle(cornerRadius: DS.Corner.chip))
                    }

                    // ── Calculate button ──────────────────────────────
                    Button(action: calculate) {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: calculated
                                  ? "checkmark.circle.fill"
                                  : "arrow.clockwise.circle.fill")
                            Text(calculated ? "Macros Recalculated" : "Calculate My Macros")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                        .background(calculated ? Color(hex: "1B7D38") : .purple)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Corner.button))
                    }
                    .animation(.easeInOut(duration: 0.3), value: calculated)

                    // ── Result card ───────────────────────────────────
                    if let r = result {
                        resultCard(r)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    Spacer(minLength: DS.Spacing.xl)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)
                .animation(.easeInOut(duration: 0.25), value: result != nil)
            }
        }
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { syncPaceKey() }
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
                        .foregroundStyle(.purple)
                }
            }
            .padding(.vertical, DS.Spacing.md)
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
                        .foregroundStyle(.purple)
                        .padding(.top, 1)
                }
            }
            .padding(.vertical, DS.Spacing.md)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func resultCard(_ r: MacroTargets) -> some View {
        VStack(spacing: DS.Spacing.md) {
            Text("Your Daily Targets")
                .font(DS.Typography.title())
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                macroCell(value: "\(r.kcal)",      label: "kcal",    color: Color(hex: "B45309"))
                Divider().frame(height: 40)
                macroCell(value: "\(r.proteinG)g", label: "protein", color: .purple)
                Divider().frame(height: 40)
                macroCell(value: "\(r.fatG)g",     label: "fat",     color: Color(hex: "1B7D38"))
                Divider().frame(height: 40)
                macroCell(value: "\(r.carbsG)g",   label: "carbs",   color: Color(hex: "5B4FCF"))
            }

            Text("These targets update across the whole app.")
                .font(DS.Typography.caption())
                .foregroundStyle(Color(.secondaryLabel))
        }
        .padding(DS.Spacing.lg)
        .background(DS.Background.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
        .shadow(color: DS.Shadow.color, radius: DS.Shadow.radius, x: 0, y: DS.Shadow.y)
    }

    private func macroCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(DS.Typography.caption())
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Calculate

    private func calculate() {
        missingStats = false

        guard let weight = effectiveWeight, weight > 0,
              heightCm > 0, ageYears > 0 else {
            missingStats = true
            Haptics.notification(.warning)
            return
        }

        // Effective pace: positive = deficit (lose), negative = surplus (gain), 0 = maintenance
        let paceValue = paces.first { $0.key == selectedPaceKey }?.value ?? 0.5
        let effectivePace: Double
        switch primaryGoal {
        case "lose":    effectivePace =  paceValue
        case "gain":    effectivePace = -paceValue
        default:        effectivePace =  0
        }
        weightLossPace = effectivePace

        result = MacroEngine.compute(
            weightKg:      weight,
            heightCm:      heightCm,
            ageYears:      ageYears,
            isMale:        biologicalSex == "male",
            activityLevel: activityLevel,
            paceKgPerWeek: effectivePace,
            proteinPerKg:  proteinPerKg,
            fatFloorPct:   fatFloorPct
        )

        Haptics.notification(.success)
        withAnimation { calculated = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { withAnimation { calculated = false } }
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
}
