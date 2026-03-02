import SwiftUI
import Charts

struct HistoryView: View {

    @EnvironmentObject private var healthKit: HealthKitManager
    @AppStorage("baselineDays") private var baselineDays: Int = 7

    private var allMetrics: [DailyMetrics] {
        var all = healthKit.baselineMetrics
        if let today = healthKit.todayMetrics { all.append(today) }
        return all.sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if allMetrics.isEmpty {
                    ContentUnavailableView(
                        "No History",
                        systemImage: "chart.line.downtrend.xyaxis",
                        description: Text("Trend data will appear here after a few days with your Apple Watch.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
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
                        .padding()
                    }
                }
            }
            .navigationTitle("Trends")
        }
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
    }
}
