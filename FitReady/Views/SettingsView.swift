import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var healthKit: HealthKitManager

    @AppStorage("anthropicAPIKey")       private var anthropicAPIKey: String = ""
    @AppStorage("sleepTargetHours")      private var sleepTargetHours: Double = 8.0

    var body: some View {
        Form {
                // MARK: Sleep
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Target")
                            Spacer()
                            Text(String(format: "%.1f hrs", sleepTargetHours))
                                .foregroundStyle(AppColors.textSecondary)
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

                // MARK: Refresh
                Section {
                    Button {
                        Task { await healthKit.loadData() }
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

                // MARK: Feedback
                Section {
                    Link(destination: URL(string: "https://fitready.canny.io")!) {
                        HStack {
                            Label("Submit feedback", systemImage: "bubble.left.and.bubble.right.fill")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(AppColors.textMuted)
                        }
                    }
                    .foregroundStyle(AppColors.textPrimary)
                } header: {
                    Text("Feedback")
                } footer: {
                    Text("Opens Canny in your browser — report bugs and vote on features.")
                }

                // MARK: Developer
                Section {
                    NavigationLink(destination: ErrorLogView()) {
                        Label("Error log", systemImage: "exclamationmark.triangle.fill")
                    }
                } header: {
                    Text("Developer")
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

    private func resetToDefaults() {
        sleepTargetHours = 8.0
    }
}
