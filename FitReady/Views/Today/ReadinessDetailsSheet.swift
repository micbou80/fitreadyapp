import SwiftUI

/// A modal sheet with simplified metric deltas and the "Updated at" timestamp.
struct ReadinessDetailsSheet: View {

    @ObservedObject var vm: TodayViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DS.Spacing.lg) {

                        // State header
                        stateHeader

                        // Metrics
                        SoftCard {
                            VStack(spacing: DS.Spacing.lg) {
                                metricRow(
                                    icon: "waveform.path.ecg",
                                    title: "HRV",
                                    value: vm.todayHRV.map { String(format: "%.0f ms", $0) } ?? "—",
                                    delta: hrvDelta,
                                    good:  isHRVGood
                                )
                                Divider()
                                metricRow(
                                    icon: "heart.fill",
                                    title: "Resting HR",
                                    value: vm.todayRHR.map { String(format: "%.0f bpm", $0) } ?? "—",
                                    delta: rhrDelta,
                                    good:  isRHRGood
                                )
                                Divider()
                                metricRow(
                                    icon: "moon.fill",
                                    title: "Sleep",
                                    value: vm.todaySleep.map { String(format: "%.1f hrs", $0) } ?? "—",
                                    delta: sleepDelta,
                                    good:  (vm.todaySleep ?? 0) >= 7.5
                                )
                            }
                        }

                        // Updated timestamp
                        if let updated = vm.lastUpdated {
                            Text("Updated \(updated.formatted(.dateTime.hour().minute()))")
                                .font(DS.Typography.caption())
                                .foregroundStyle(AppColors.textMuted)
                        }
                    }
                    .padding(DS.Spacing.lg)
                }
            }
            .navigationTitle("Recovery Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - State header

    private var stateHeader: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: stateIcon)
                .font(.system(size: 22))
                .foregroundStyle(DS.StateColor.primary(for: vm.readinessState))
                .frame(width: 44, height: 44)
                .background(DS.StateColor.primary(for: vm.readinessState).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(stateLabel)
                    .font(DS.Typography.title())
                    .foregroundStyle(DS.StateColor.primary(for: vm.readinessState))
                if !vm.readinessReason.isEmpty {
                    Text(vm.readinessReason)
                        .font(DS.Typography.caption())
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            Spacer()
        }
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Corner.card)
                .fill(DS.StateColor.background(for: vm.readinessState))
        )
    }

    private var stateIcon: String {
        switch vm.readinessState {
        case .green:  return "bolt.fill"
        case .yellow: return "figure.walk"
        case .red:    return "moon.zzz.fill"
        }
    }

    private var stateLabel: String {
        switch vm.readinessState {
        case .green:  return "Ready to train"
        case .yellow: return "Go lighter"
        case .red:    return "Rest day"
        }
    }

    // MARK: - Metric row

    @ViewBuilder
    private func metricRow(icon: String, title: String, value: String,
                            delta: String?, good: Bool) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(good ? AppColors.greenText : AppColors.redText)
                .frame(width: 26)

            Text(title)
                .font(DS.Typography.body())

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                if let d = delta {
                    Text(d)
                        .font(DS.Typography.caption())
                        .foregroundStyle(good ? AppColors.greenText : AppColors.redText)
                }
            }
        }
    }

    // MARK: - Delta helpers

    private var isHRVGood: Bool {
        guard let hrv = vm.todayHRV, let base = vm.baselineHRV, base > 0 else { return false }
        return hrv >= base * 0.95
    }

    private var isRHRGood: Bool {
        guard let rhr = vm.todayRHR, let base = vm.baselineRHR, base > 0 else { return false }
        return rhr <= base * 1.03
    }

    private var hrvDelta: String? {
        guard let hrv = vm.todayHRV, let base = vm.baselineHRV, base > 0 else { return nil }
        let pct = Int(((hrv - base) / base * 100).rounded())
        return (pct >= 0 ? "+" : "") + "\(pct)% vs avg"
    }

    private var rhrDelta: String? {
        guard let rhr = vm.todayRHR, let base = vm.baselineRHR, base > 0 else { return nil }
        let pct = Int(((rhr - base) / base * 100).rounded())
        return (pct <= 0 ? "" : "+") + "\(pct)% vs avg"
    }

    private var sleepDelta: String? {
        guard let sleep = vm.todaySleep else { return nil }
        let diff = sleep - 7.5
        return (diff >= 0 ? "+" : "") + String(format: "%.1f hrs vs target", diff)
    }
}
