import SwiftUI

struct ProfileView: View {

    @EnvironmentObject private var healthKit: HealthKitManager

    @AppStorage("goalWeightKg")      private var goalWeight: Double = 0
    @AppStorage("manualWeightKg")    private var manualWeight: Double = 0
    @AppStorage("useManualWeight")   private var useManualWeight: Bool = false
    @AppStorage("goalBodyFatPct")    private var goalBodyFat: Double = 0
    @AppStorage("manualBodyFatPct")  private var manualBodyFat: Double = 0
    @AppStorage("useManualBodyFat")  private var useManualBodyFat: Bool = false

    @State private var goalWeightText: String = ""
    @State private var manualWeightText: String = ""
    @State private var goalBodyFatText: String = ""
    @State private var manualBodyFatText: String = ""
    @FocusState private var focusedField: Field?

    private enum Field { case goalWeight, manualWeight, goalBodyFat, manualBodyFat }

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

                        // MARK: Weight summary card
                        if let cw = currentWeight, goalWeight > 0 {
                            weightSummaryCard(current: cw, goal: goalWeight)
                        }

                        // MARK: Goal weight
                        formCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Label("Goal Weight", systemImage: "flag.fill")
                                    .font(.headline)

                                HStack {
                                    TextField("e.g. 75", text: $goalWeightText)
                                        .keyboardType(.decimalPad)
                                        .focused($focusedField, equals: .goalWeight)
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                        .onSubmit { saveGoalWeight() }

                                    Text("kg")
                                        .font(.title2)
                                        .foregroundStyle(Color(.secondaryLabel))
                                }

                                if goalWeight > 0 {
                                    Text("Current goal: \(String(format: "%.1f", goalWeight)) kg")
                                        .font(.caption)
                                        .foregroundStyle(Color(.secondaryLabel))
                                }

                                Button("Save Goal") { saveGoalWeight() }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(goalWeightText.isEmpty)
                            }
                        }

                        // MARK: Current weight
                        formCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Label("Current Weight", systemImage: "scalemass.fill")
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
                                        Image(systemName: "heart.fill")
                                            .foregroundStyle(.red)
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

                        Text("Weight data from Apple Health updates automatically when you weigh yourself.")
                            .font(.caption)
                            .foregroundStyle(Color(.tertiaryLabel))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        // MARK: Body fat summary card
                        if let bf = currentBodyFat, goalBodyFat > 0 {
                            bodyFatSummaryCard(current: bf, goal: goalBodyFat)
                        }

                        // MARK: Goal body fat
                        formCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Label("Goal Body Fat", systemImage: "chart.bar.fill")
                                    .font(.headline)

                                HStack {
                                    TextField("e.g. 15", text: $goalBodyFatText)
                                        .keyboardType(.decimalPad)
                                        .focused($focusedField, equals: .goalBodyFat)
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                        .onSubmit { saveGoalBodyFat() }

                                    Text("%")
                                        .font(.title2)
                                        .foregroundStyle(Color(.secondaryLabel))
                                }

                                if goalBodyFat > 0 {
                                    Text("Current goal: \(String(format: "%.1f", goalBodyFat))%")
                                        .font(.caption)
                                        .foregroundStyle(Color(.secondaryLabel))
                                }

                                Button("Save Goal") { saveGoalBodyFat() }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(goalBodyFatText.isEmpty)
                            }
                        }

                        // MARK: Current body fat
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
                                        Image(systemName: "heart.fill")
                                            .foregroundStyle(.red)
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

                        Text("Body fat data from Apple Health updates when synced from a compatible scale.")
                            .font(.caption)
                            .foregroundStyle(Color(.tertiaryLabel))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                }
                .onTapGesture { focusedField = nil }
            }
            .navigationTitle("Profile")
            .onAppear {
                if goalWeight > 0 { goalWeightText = String(format: "%.1f", goalWeight) }
                if manualWeight > 0 { manualWeightText = String(format: "%.1f", manualWeight) }
                if goalBodyFat > 0 { goalBodyFatText = String(format: "%.1f", goalBodyFat) }
                if manualBodyFat > 0 { manualBodyFatText = String(format: "%.1f", manualBodyFat) }
            }
        }
    }

    // MARK: - Weight summary card

    @ViewBuilder
    private func weightSummaryCard(current: Double, goal: Double) -> some View {
        let delta = current - goal
        let isLosing = delta > 0
        let progress = max(0, min(1, 1 - abs(delta) / max(current, goal)))

        VStack(spacing: 16) {
            HStack(spacing: 0) {
                Spacer()
                VStack(spacing: 4) {
                    Text(String(format: "%.1f", current))
                        .font(.system(size: 36, weight: .black, design: .rounded))
                    Text("now (kg)")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }
                Spacer()
                Image(systemName: isLosing ? "arrow.down" : "arrow.up")
                    .font(.title2)
                    .foregroundStyle(isLosing ? Color(red: 1.0, green: 0.55, blue: 0.26) : Color(red: 0.20, green: 0.78, blue: 0.35))
                Spacer()
                VStack(spacing: 4) {
                    Text(String(format: "%.1f", goal))
                        .font(.system(size: 36, weight: .black, design: .rounded))
                    Text("goal (kg)")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }
                Spacer()
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5))
                            .frame(height: 10)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isLosing ? Color(red: 1.0, green: 0.55, blue: 0.26) : Color(red: 0.20, green: 0.78, blue: 0.35))
                            .frame(width: geo.size.width * progress, height: 10)
                    }
                }
                .frame(height: 10)

                HStack {
                    Text(String(format: "%.1f kg to go", abs(delta)))
                        .font(.subheadline).fontWeight(.semibold)
                    Spacer()
                    Text(String(format: "%.0f%%", progress * 100))
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func formCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private func saveGoalWeight() {
        if let v = Double(goalWeightText.replacingOccurrences(of: ",", with: ".")) {
            goalWeight = v
        }
        focusedField = nil
    }

    private func saveManualWeight() {
        if let v = Double(manualWeightText.replacingOccurrences(of: ",", with: ".")) {
            manualWeight = v
        }
        focusedField = nil
    }

    // MARK: - Body fat summary card

    @ViewBuilder
    private func bodyFatSummaryCard(current: Double, goal: Double) -> some View {
        let delta = current - goal
        let isDecreasing = delta > 0
        let progress = max(0, min(1, 1 - abs(delta) / max(current, goal)))

        VStack(spacing: 16) {
            HStack(spacing: 0) {
                Spacer()
                VStack(spacing: 4) {
                    Text(String(format: "%.1f", current))
                        .font(.system(size: 36, weight: .black, design: .rounded))
                    Text("now (%)")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }
                Spacer()
                Image(systemName: isDecreasing ? "arrow.down" : "arrow.up")
                    .font(.title2)
                    .foregroundStyle(isDecreasing ? Color(red: 1.0, green: 0.55, blue: 0.26) : Color(red: 0.20, green: 0.78, blue: 0.35))
                Spacer()
                VStack(spacing: 4) {
                    Text(String(format: "%.1f", goal))
                        .font(.system(size: 36, weight: .black, design: .rounded))
                    Text("goal (%)")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5))
                            .frame(height: 10)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isDecreasing ? Color(red: 1.0, green: 0.55, blue: 0.26) : Color(red: 0.20, green: 0.78, blue: 0.35))
                            .frame(width: geo.size.width * progress, height: 10)
                    }
                }
                .frame(height: 10)

                HStack {
                    Text(String(format: "%.1f%% to go", abs(delta)))
                        .font(.subheadline).fontWeight(.semibold)
                    Spacer()
                    Text(String(format: "%.0f%%", progress * 100))
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private func saveGoalBodyFat() {
        if let v = Double(goalBodyFatText.replacingOccurrences(of: ",", with: ".")) {
            goalBodyFat = v
        }
        focusedField = nil
    }

    private func saveManualBodyFat() {
        if let v = Double(manualBodyFatText.replacingOccurrences(of: ",", with: ".")) {
            manualBodyFat = v
        }
        focusedField = nil
    }
}
