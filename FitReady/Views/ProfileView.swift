import SwiftUI

struct ProfileView: View {

    @EnvironmentObject private var healthKit: HealthKitManager

    @AppStorage("startWeightKg")     private var startWeight: Double = 0
    @AppStorage("goalWeightKg")      private var goalWeight: Double = 0
    @AppStorage("manualWeightKg")    private var manualWeight: Double = 0
    @AppStorage("useManualWeight")   private var useManualWeight: Bool = false
    @AppStorage("startBodyFatPct")   private var startBodyFat: Double = 0
    @AppStorage("goalBodyFatPct")    private var goalBodyFat: Double = 0
    @AppStorage("manualBodyFatPct")  private var manualBodyFat: Double = 0
    @AppStorage("useManualBodyFat")  private var useManualBodyFat: Bool = false

    @State private var startWeightText: String = ""
    @State private var goalWeightText: String = ""
    @State private var manualWeightText: String = ""
    @State private var startBodyFatText: String = ""
    @State private var goalBodyFatText: String = ""
    @State private var manualBodyFatText: String = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case startWeight, goalWeight, manualWeight
        case startBodyFat, goalBodyFat, manualBodyFat
    }

    private var currentWeight: Double? {
        if useManualWeight { return manualWeight > 0 ? manualWeight : nil }
        return healthKit.currentWeightKg ?? (manualWeight > 0 ? manualWeight : nil)
    }

    private var currentBodyFat: Double? {
        if useManualBodyFat { return manualBodyFat > 0 ? manualBodyFat : nil }
        return healthKit.currentBodyFatPct ?? (manualBodyFat > 0 ? manualBodyFat : nil)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // ── WEIGHT ───────────────────────────────────

                        sectionHeader("Weight", icon: "scalemass.fill")

                        if let cw = currentWeight, goalWeight > 0 {
                            WeightCardView(
                                current: cw,
                                goal: goalWeight,
                                start: startWeight > 0 ? startWeight : nil
                            )
                        }

                        formCard {
                            inputSection(
                                title: "Starting Weight",
                                icon: "flag.checkered",
                                hint: "e.g. 85",
                                unit: "kg",
                                text: $startWeightText,
                                field: .startWeight,
                                savedValue: startWeight > 0 ? String(format: "%.1f kg saved", startWeight) : nil,
                                buttonLabel: "Save Starting Weight",
                                tint: .purple,
                                onSave: saveStartWeight
                            )
                        }

                        formCard {
                            inputSection(
                                title: "Goal Weight",
                                icon: "flag.fill",
                                hint: "e.g. 72",
                                unit: "kg",
                                text: $goalWeightText,
                                field: .goalWeight,
                                savedValue: goalWeight > 0 ? String(format: "%.1f kg saved", goalWeight) : nil,
                                buttonLabel: "Save Goal",
                                tint: .accentColor,
                                onSave: saveGoalWeight
                            )
                        }

                        formCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Label("Current Weight", systemImage: "scalemass")
                                    .font(.headline)

                                if let hkWeight = healthKit.currentWeightKg {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(String(format: "%.1f kg", hkWeight))
                                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                            Text("From Apple Health")
                                                .font(.caption)
                                                .foregroundStyle(Color(.secondaryLabel))
                                        }
                                        Spacer()
                                        Image(systemName: "heart.fill").foregroundStyle(.red)
                                    }
                                    Toggle("Use manual entry instead", isOn: $useManualWeight)
                                        .font(.subheadline)
                                }

                                if useManualWeight || healthKit.currentWeightKg == nil {
                                    HStack {
                                        TextField("e.g. 78.5", text: $manualWeightText)
                                            .keyboardType(.decimalPad)
                                            .focused($focusedField, equals: .manualWeight)
                                            .font(.system(size: 32, weight: .bold, design: .rounded))
                                            .onSubmit { saveManualWeight() }
                                        Text("kg")
                                            .font(.title2)
                                            .foregroundStyle(Color(.secondaryLabel))
                                    }
                                    Button("Save Weight") { saveManualWeight() }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.orange)
                                        .disabled(manualWeightText.isEmpty)
                                }
                            }
                        }

                        disclaimer("Weight from Apple Health updates automatically when you weigh yourself.")

                        // ── BODY FAT ─────────────────────────────────

                        sectionHeader("Body Fat", icon: "figure.stand")

                        if let bf = currentBodyFat, goalBodyFat > 0 {
                            BodyFatCardView(
                                current: bf,
                                goal: goalBodyFat,
                                start: startBodyFat > 0 ? startBodyFat : nil
                            )
                        }

                        formCard {
                            inputSection(
                                title: "Starting Body Fat",
                                icon: "flag.checkered",
                                hint: "e.g. 26",
                                unit: "%",
                                text: $startBodyFatText,
                                field: .startBodyFat,
                                savedValue: startBodyFat > 0 ? String(format: "%.1f%% saved", startBodyFat) : nil,
                                buttonLabel: "Save Starting Body Fat",
                                tint: .purple,
                                onSave: saveStartBodyFat
                            )
                        }

                        formCard {
                            inputSection(
                                title: "Goal Body Fat",
                                icon: "chart.bar.fill",
                                hint: "e.g. 18",
                                unit: "%",
                                text: $goalBodyFatText,
                                field: .goalBodyFat,
                                savedValue: goalBodyFat > 0 ? String(format: "%.1f%% saved", goalBodyFat) : nil,
                                buttonLabel: "Save Goal",
                                tint: .accentColor,
                                onSave: saveGoalBodyFat
                            )
                        }

                        formCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Label("Current Body Fat", systemImage: "figure.stand")
                                    .font(.headline)

                                if let hkBF = healthKit.currentBodyFatPct {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(String(format: "%.1f%%", hkBF))
                                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                            Text("From Apple Health")
                                                .font(.caption)
                                                .foregroundStyle(Color(.secondaryLabel))
                                        }
                                        Spacer()
                                        Image(systemName: "heart.fill").foregroundStyle(.red)
                                    }
                                    Toggle("Use manual entry instead", isOn: $useManualBodyFat)
                                        .font(.subheadline)
                                }

                                if useManualBodyFat || healthKit.currentBodyFatPct == nil {
                                    HStack {
                                        TextField("e.g. 22.5", text: $manualBodyFatText)
                                            .keyboardType(.decimalPad)
                                            .focused($focusedField, equals: .manualBodyFat)
                                            .font(.system(size: 32, weight: .bold, design: .rounded))
                                            .onSubmit { saveManualBodyFat() }
                                        Text("%")
                                            .font(.title2)
                                            .foregroundStyle(Color(.secondaryLabel))
                                    }
                                    Button("Save Body Fat") { saveManualBodyFat() }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.orange)
                                        .disabled(manualBodyFatText.isEmpty)
                                }
                            }
                        }

                        disclaimer("Body fat from Apple Health updates when synced from a compatible scale.")
                    }
                    .padding()
                }
                .onTapGesture { focusedField = nil }
            }
            .navigationTitle("Profile")
            .onAppear {
                if startWeight   > 0 { startWeightText   = String(format: "%.1f", startWeight)   }
                if goalWeight    > 0 { goalWeightText    = String(format: "%.1f", goalWeight)    }
                if manualWeight  > 0 { manualWeightText  = String(format: "%.1f", manualWeight)  }
                if startBodyFat  > 0 { startBodyFatText  = String(format: "%.1f", startBodyFat)  }
                if goalBodyFat   > 0 { goalBodyFatText   = String(format: "%.1f", goalBodyFat)   }
                if manualBodyFat > 0 { manualBodyFatText = String(format: "%.1f", manualBodyFat) }
            }
        }
    }

    // MARK: - Layout helpers

    @ViewBuilder
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(Color.accentColor)
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(.secondaryLabel))
                .kerning(0.8)
            Spacer()
        }
        .padding(.top, 4)
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private func formCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private func inputSection(
        title: String,
        icon: String,
        hint: String,
        unit: String,
        text: Binding<String>,
        field: Field,
        savedValue: String?,
        buttonLabel: String,
        tint: Color,
        onSave: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon).font(.headline)

            HStack {
                TextField(hint, text: text)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: field)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .onSubmit { onSave() }
                Text(unit)
                    .font(.title2)
                    .foregroundStyle(Color(.secondaryLabel))
            }

            if let saved = savedValue {
                Text(saved)
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
            }

            Button(buttonLabel, action: onSave)
                .buttonStyle(.borderedProminent)
                .tint(tint)
                .disabled(text.wrappedValue.isEmpty)
        }
    }

    @ViewBuilder
    private func disclaimer(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Color(.tertiaryLabel))
            .multilineTextAlignment(.center)
            .padding(.horizontal)
    }

    // MARK: - Save helpers

    private func saveStartWeight() {
        if let v = Double(startWeightText.replacingOccurrences(of: ",", with: ".")) { startWeight = v }
        focusedField = nil
    }

    private func saveGoalWeight() {
        if let v = Double(goalWeightText.replacingOccurrences(of: ",", with: ".")) { goalWeight = v }
        focusedField = nil
    }

    private func saveManualWeight() {
        if let v = Double(manualWeightText.replacingOccurrences(of: ",", with: ".")) { manualWeight = v }
        focusedField = nil
    }

    private func saveStartBodyFat() {
        if let v = Double(startBodyFatText.replacingOccurrences(of: ",", with: ".")) { startBodyFat = v }
        focusedField = nil
    }

    private func saveGoalBodyFat() {
        if let v = Double(goalBodyFatText.replacingOccurrences(of: ",", with: ".")) { goalBodyFat = v }
        focusedField = nil
    }

    private func saveManualBodyFat() {
        if let v = Double(manualBodyFatText.replacingOccurrences(of: ",", with: ".")) { manualBodyFat = v }
        focusedField = nil
    }
}
