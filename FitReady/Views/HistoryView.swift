import SwiftUI
import Charts

struct InsightsView: View {

    @EnvironmentObject private var healthKit: HealthKitManager

    // Settings for score computation
    @AppStorage("baselineDays")          private var baselineDays: Int    = 7
    @AppStorage("sleepTargetHours")      private var sleepTargetHours: Double = 7.5
    @AppStorage("hrvGoodThreshold")      private var hrvGoodThreshold: Double = 0.95
    @AppStorage("hrvNeutralThreshold")   private var hrvNeutralThreshold: Double = 0.80
    @AppStorage("rhrGoodThreshold")      private var rhrGoodThreshold: Double = 1.03
    @AppStorage("rhrNeutralThreshold")   private var rhrNeutralThreshold: Double = 1.08

    // Body composition
    @AppStorage("goalWeightKg")          private var goalWeight: Double = 0
    @AppStorage("manualWeightKg")        private var manualWeight: Double = 0
    @AppStorage("useManualWeight")       private var useManualWeight: Bool = false
    @AppStorage("goalBodyFatPct")        private var goalBodyFat: Double = 0
    @AppStorage("manualBodyFatPct")      private var manualBodyFat: Double = 0
    @AppStorage("useManualBodyFat")      private var useManualBodyFat: Bool = false
    @AppStorage("startWeightKg")         private var startWeight: Double = 0
    @AppStorage("startBodyFatPct")       private var startBodyFat: Double = 0

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

    private var allMetrics: [DailyMetrics] {
        var all = healthKit.baselineMetrics
        if let today = healthKit.todayMetrics { all.append(today) }
        return all.sorted { $0.date < $1.date }
    }

    private var displayWeight: Double? {
        if useManualWeight { return manualWeight > 0 ? manualWeight : nil }
        return healthKit.currentWeightKg
    }

    private var displayBodyFat: Double? {
        if useManualBodyFat { return manualBodyFat > 0 ? manualBodyFat : nil }
        return healthKit.currentBodyFatPct
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if allMetrics.isEmpty && readinessScore == nil {
                    ContentUnavailableView(
                        "No Data Yet",
                        systemImage: "chart.line.downtrend.xyaxis",
                        description: Text("Wear your Apple Watch overnight and check back tomorrow.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 20) {

                            // MARK: Today's Metrics
                            if let score = readinessScore {
                                insightsSectionHeader("Recovery Metrics")
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
                            }

                            // MARK: Body Composition
                            let hasWeight = (displayWeight != nil && goalWeight > 0)
                            let hasBF     = (displayBodyFat != nil && goalBodyFat > 0)
                            if hasWeight || hasBF {
                                insightsSectionHeader("Body Composition")
                                if let wt = displayWeight, goalWeight > 0 {
                                    WeightCardView(
                                        current: wt,
                                        goal: goalWeight,
                                        start: startWeight > 0 ? startWeight : nil
                                    )
                                    .padding(.horizontal, 16)
                                }
                                if let bf = displayBodyFat, goalBodyFat > 0 {
                                    BodyFatCardView(
                                        current: bf,
                                        goal: goalBodyFat,
                                        start: startBodyFat > 0 ? startBodyFat : nil
                                    )
                                    .padding(.horizontal, 16)
                                }
                            }

                            // MARK: Trends
                            if !allMetrics.isEmpty {
                                insightsSectionHeader("Trends")
                                MetricChart(
                                    title: "HRV",
                                    unit: "ms",
                                    color: Color(red: 0.20, green: 0.78, blue: 0.35),
                                    data: allMetrics.compactMap { m in
                                        m.hrv.map { ChartPoint(date: m.date, value: $0) }
                                    }
                                )
                                MetricChart(
                                    title: "Resting HR",
                                    unit: "bpm",
                                    color: Color(red: 1.00, green: 0.55, blue: 0.26),
                                    data: allMetrics.compactMap { m in
                                        m.rhr.map { ChartPoint(date: m.date, value: $0) }
                                    },
                                    higherIsBetter: false
                                )
                                MetricChart(
                                    title: "Sleep",
                                    unit: "hrs",
                                    color: Color(red: 0.40, green: 0.52, blue: 0.98),
                                    data: allMetrics.compactMap { m in
                                        m.sleepHours.map { ChartPoint(date: m.date, value: $0) }
                                    }
                                )
                            }

                            Spacer(minLength: 16)
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Insights")
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func insightsSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline).fontWeight(.semibold)
            .foregroundStyle(Color(.secondaryLabel))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 4)
    }

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

// MARK: - Chart Data

struct ChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

// MARK: - Metric Chart Card

private struct MetricChart: View {

    let title: String
    let unit: String
    let color: Color
    let data: [ChartPoint]
    var higherIsBetter: Bool = true

    private var average: Double {
        guard !data.isEmpty else { return 0 }
        return data.map(\.value).reduce(0, +) / Double(data.count)
    }

    private func pointColor(_ point: ChartPoint) -> Color {
        guard average > 0 else { return color }
        let pct = (point.value - average) / average
        let isGood = higherIsBetter ? pct > 0.04 : pct < -0.04
        let isBad  = higherIsBetter ? pct < -0.12 : pct > 0.07
        if isGood { return Color(red: 0.20, green: 0.78, blue: 0.35) }
        if isBad  { return Color(red: 0.88, green: 0.36, blue: 0.36) }
        return Color(red: 1.00, green: 0.55, blue: 0.26)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                Spacer()
                if average > 0 {
                    Text("Avg \(String(format: unit == "hrs" ? "%.1f" : "%.0f", average)) \(unit)")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }

            if data.isEmpty {
                Text("No data available")
                    .font(.caption)
                    .foregroundStyle(Color(.tertiaryLabel))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 110)
            } else {
                Chart {
                    ForEach(data) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value(title, point.value)
                        )
                        .foregroundStyle(color.opacity(0.4))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value(title, point.value)
                        )
                        .foregroundStyle(pointColor(point))
                        .symbolSize(55)
                    }

                    if average > 0 {
                        RuleMark(y: .value("Avg", average))
                            .foregroundStyle(Color(.systemGray4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .annotation(position: .trailing, alignment: .center) {
                                Text("avg")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color(.tertiaryLabel))
                            }
                    }
                }
                .frame(height: 110)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                            .font(.system(size: 10))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                        AxisValueLabel()
                            .font(.system(size: 10))
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 16)
    }
}
