import SwiftUI

struct MainReadinessView: View {

    @EnvironmentObject private var healthKit: HealthKitManager

    @AppStorage("baselineDays")          private var baselineDays: Int = 7
    @AppStorage("sleepTargetHours")      private var sleepTargetHours: Double = 7.5
    @AppStorage("hrvGoodThreshold")      private var hrvGoodThreshold: Double = 0.95
    @AppStorage("hrvNeutralThreshold")   private var hrvNeutralThreshold: Double = 0.80
    @AppStorage("rhrGoodThreshold")      private var rhrGoodThreshold: Double = 1.03
    @AppStorage("rhrNeutralThreshold")   private var rhrNeutralThreshold: Double = 1.08

    // MARK: - Computed

    private var settings: AppSettings {
        AppSettings(
            baselineDays: baselineDays,
            sleepTargetHours: sleepTargetHours,
            hrvGoodThreshold: hrvGoodThreshold,
            hrvNeutralThreshold: hrvNeutralThreshold,
            rhrGoodThreshold: rhrGoodThreshold,
            rhrNeutralThreshold: rhrNeutralThreshold
        )
    }

    private var readinessScore: ReadinessScore? {
        guard let today = healthKit.todayMetrics,
              !healthKit.baselineMetrics.isEmpty else { return nil }
        return ReadinessEngine.compute(today: today, baseline: healthKit.baselineMetrics, settings: settings)
    }

    private var dateLabel: String {
        Date().formatted(.dateTime.weekday(.wide).month().day())
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if let error = healthKit.authError {
                    errorView(message: error)
                } else if healthKit.isLoading && healthKit.todayMetrics == nil {
                    loadingView
                } else if let score = readinessScore {
                    mainContent(score: score)
                } else {
                    noDataView
                }
            }
            .navigationTitle(dateLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if healthKit.isLoading {
                    ToolbarItem(placement: .topBarTrailing) {
                        ProgressView().scaleEffect(0.8)
                    }
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            ) { _ in
                Task { await healthKit.loadData(baselineDays: baselineDays) }
            }
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private func mainContent(score: ReadinessScore) -> some View {
        ScrollView {
            VStack(spacing: 28) {
                // Verdict label
                VStack(spacing: 6) {
                    Text(score.verdict.label)
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(score.verdict.color)

                    Text(score.verdict.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                // Ring
                ReadinessRingView(score: score)

                // Metric cards
                HStack(spacing: 10) {
                    MetricCardView(
                        title: "HRV",
                        value: score.todayHRV.map { String(format: "%.0f", $0) } ?? "—",
                        unit: "ms",
                        delta: percentDelta(today: score.todayHRV, baseline: score.baselineHRV, invert: false),
                        icon: "waveform.path.ecg",
                        score: score.hrvScore
                    )
                    MetricCardView(
                        title: "Resting HR",
                        value: score.todayRHR.map { String(format: "%.0f", $0) } ?? "—",
                        unit: "bpm",
                        delta: percentDelta(today: score.todayRHR, baseline: score.baselineRHR, invert: true),
                        icon: "heart.fill",
                        score: score.rhrScore
                    )
                    MetricCardView(
                        title: "Sleep",
                        value: score.todaySleep.map { String(format: "%.1f", $0) } ?? "—",
                        unit: "hrs",
                        delta: sleepDelta(today: score.todaySleep),
                        icon: "moon.fill",
                        score: score.sleepScore
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: - States

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.4)
            Text("Loading your data…")
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
        }
    }

    @ViewBuilder
    private var noDataView: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 64))
                .foregroundStyle(Color(.tertiaryLabel))

            VStack(spacing: 8) {
                Text("No Data Yet")
                    .font(.title3).bold()
                Text("Wear your Apple Watch overnight and check back tomorrow for your first readiness score.")
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabel))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button("Retry") {
                Task { await healthKit.loadData(baselineDays: baselineDays) }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.slash")
                .font(.system(size: 64))
                .foregroundStyle(Color(.tertiaryLabel))

            VStack(spacing: 8) {
                Text("HealthKit Access Required")
                    .font(.title3).bold()
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabel))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
    }

    // MARK: - Helpers

    private func percentDelta(today: Double?, baseline: Double?, invert: Bool) -> Double? {
        guard let t = today, let b = baseline, b > 0 else { return nil }
        let raw = ((t - b) / b) * 100
        return invert ? -raw : raw
    }

    private func sleepDelta(today: Double?) -> Double? {
        guard let t = today else { return nil }
        return ((t - sleepTargetHours) / sleepTargetHours) * 100
    }
}
