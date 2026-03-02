import SwiftUI

struct ProfileView: View {

    @EnvironmentObject private var healthKit: HealthKitManager

    @AppStorage("goalWeightKg")    private var goalWeight: Double = 0
    @AppStorage("manualWeightKg")  private var manualWeight: Double = 0
    @AppStorage("useManualWeight") private var useManualWeight: Bool = false

    @State private var goalWeightText: String = ""
    @State private var manualWeightText: String = ""
    @FocusState private var focusedField: Field?

    private enum Field { case goal, manual }

    private var currentWeight: Double? {
        if useManualWeight { return manualWeight > 0 ? manualWeight : nil }
        return healthKit.currentWeightKg ?? (manualWeight > 0 ? manualWeight : nil)
    }

    private var kgToGoal: Double? {
        guard let cw = currentWeight, goalWeight > 0 else { return nil }
        return cw - goalWeight
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
                                        .focused($focusedField, equals: .goal)
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
                                            .focused($focusedField, equals: .manual)
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
                    }
                    .padding()
                }
                .onTapGesture { focusedField = nil }
            }
            .navigationTitle("Profile")
            .onAppear {
                if goalWeight > 0 { goalWeightText = String(format: "%.1f", goalWeight) }
                if manualWeight > 0 { manualWeightText = String(format: "%.1f", manualWeight) }
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
}
