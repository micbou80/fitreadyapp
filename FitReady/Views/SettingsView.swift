import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var healthKit: HealthKitManager

    @AppStorage("anthropicAPIKey")       private var anthropicAPIKey: String = ""
    @AppStorage("baselineDays")          private var baselineDays: Int = 7
    @AppStorage("sleepTargetHours")      private var sleepTargetHours: Double = 7.5
    @AppStorage("hrvGoodThreshold")      private var hrvGoodThreshold: Double = 0.95
    @AppStorage("hrvNeutralThreshold")   private var hrvNeutralThreshold: Double = 0.80
    @AppStorage("rhrGoodThreshold")      private var rhrGoodThreshold: Double = 1.03
    @AppStorage("rhrNeutralThreshold")   private var rhrNeutralThreshold: Double = 1.08

    var body: some View {
        Form {
                // MARK: Baseline
                Section {
                    Stepper("**\(baselineDays)** days", value: $baselineDays, in: 5...14)
                } header: {
                    Text("Baseline Window")
                } footer: {
                    Text("How many past days are used to calculate your personal averages.")
                }

                // MARK: Sleep
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Target")
                            Spacer()
                            Text(String(format: "%.1f hrs", sleepTargetHours))
                                .foregroundStyle(Color(.secondaryLabel))
                                .monospacedDigit()
                        }
                        Slider(value: $sleepTargetHours, in: 6.0...10.0, step: 0.5)
                            .tint(AppColors.dataSleep)
                    }
                } header: {
                    Text("Sleep Target")
                } footer: {
                    Text("Sleeping at or above this target contributes positively to your score.")
                }

                // MARK: HRV
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        thresholdRow(
                            label: "Good",
                            description: "HRV ≥ \(Int(hrvGoodThreshold * 100))% of baseline",
                            value: $hrvGoodThreshold,
                            range: 0.80...1.00,
                            color: AppColors.greenBase
                        )
                        thresholdRow(
                            label: "Neutral",
                            description: "HRV ≥ \(Int(hrvNeutralThreshold * 100))% of baseline",
                            value: $hrvNeutralThreshold,
                            range: 0.60...0.90,
                            color: AppColors.amberBase
                        )
                    }
                } header: {
                    Text("HRV Thresholds")
                } footer: {
                    Text("How much your HRV can drop from your baseline before hurting your score.")
                }

                // MARK: RHR
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        thresholdRow(
                            label: "Good",
                            description: "RHR ≤ +\(Int((rhrGoodThreshold - 1.0) * 100))% of baseline",
                            value: $rhrGoodThreshold,
                            range: 1.00...1.10,
                            color: AppColors.greenBase
                        )
                        thresholdRow(
                            label: "Neutral",
                            description: "RHR ≤ +\(Int((rhrNeutralThreshold - 1.0) * 100))% of baseline",
                            value: $rhrNeutralThreshold,
                            range: 1.01...1.20,
                            color: AppColors.amberBase
                        )
                    }
                } header: {
                    Text("Resting HR Thresholds")
                } footer: {
                    Text("How much your resting heart rate can rise above baseline before hurting your score.")
                }

                // MARK: Refresh
                Section {
                    Button {
                        Task { await healthKit.loadData(baselineDays: baselineDays) }
                    } label: {
                        HStack {
                            Label("Refresh Data", systemImage: "arrow.clockwise")
                            Spacer()
                            if healthKit.isLoading {
                                ProgressView().scaleEffect(0.8)
                            }
                        }
                    }
                }

                // MARK: AI Scanner
                Section {
                    SecureField("Paste your key here", text: $anthropicAPIKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Link(destination: URL(string: "https://console.anthropic.com/settings/keys")!) {
                        HStack {
                            Text("Get a free API key")
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                        .foregroundStyle(AppColors.accent)
                    }
                } header: {
                    Text("AI Scanner")
                } footer: {
                    Text("Used for meal photo analysis. Your key is stored locally and never shared.")
                }

                // MARK: Reset
                Section {
                    Button(role: .destructive) {
                        resetToDefaults()
                    } label: {
                        Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                    }
                }
            }
        .navigationTitle("Settings")
    }

    // MARK: - Helpers

    @ViewBuilder
    private func thresholdRow(
        label: String,
        description: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.subheadline).fontWeight(.medium)
                Spacer()
                Text(description)
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
                    .monospacedDigit()
            }
            Slider(value: value, in: range, step: 0.01).tint(color)
        }
    }

    private func resetToDefaults() {
        baselineDays        = 7
        sleepTargetHours    = 7.5
        hrvGoodThreshold    = 0.95
        hrvNeutralThreshold = 0.80
        rhrGoodThreshold    = 1.03
        rhrNeutralThreshold = 1.08
    }
}
