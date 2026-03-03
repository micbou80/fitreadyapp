import SwiftUI

struct MacroSummaryCard: View {

    let targets: MacroTargets
    /// nil values mean "no data yet today"
    let actualKcal: Double?
    let actualProteinG: Double?
    let actualFatG: Double?
    let actualCarbsG: Double?

    private var hasAnyActual: Bool {
        actualKcal != nil || actualProteinG != nil || actualFatG != nil || actualCarbsG != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // ── Header ───────────────────────────────────
            HStack {
                Label("Today's Macros", systemImage: "fork.knife")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color(.secondaryLabel))
                Spacer()
                if !hasAnyActual {
                    Text("No data yet")
                        .font(.caption)
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }

            // ── Four columns ─────────────────────────────
            HStack(spacing: 8) {
                macroColumn(
                    label: "kcal",
                    actual: actualKcal.map { Int($0.rounded()) },
                    target: targets.kcal,
                    color: Color(red: 0.58, green: 0.35, blue: 0.96),  // purple
                    format: { "\($0)" }
                )
                macroColumn(
                    label: "protein",
                    actual: actualProteinG.map { Int($0.rounded()) },
                    target: targets.proteinG,
                    color: Color(red: 0.20, green: 0.78, blue: 0.35),  // green
                    format: { "\($0)g" }
                )
                macroColumn(
                    label: "fat",
                    actual: actualFatG.map { Int($0.rounded()) },
                    target: targets.fatG,
                    color: Color(red: 1.00, green: 0.55, blue: 0.26),  // orange
                    format: { "\($0)g" }
                )
                macroColumn(
                    label: "carbs",
                    actual: actualCarbsG.map { Int($0.rounded()) },
                    target: targets.carbsG,
                    color: Color(red: 0.26, green: 0.59, blue: 0.98),  // blue
                    format: { "\($0)g" }
                )
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private func macroColumn(
        label: String,
        actual: Int?,
        target: Int,
        color: Color,
        format: (Int) -> String
    ) -> some View {
        let progress = actual.map { min(1.0, Double($0) / Double(max(1, target))) } ?? 0

        VStack(alignment: .leading, spacing: 6) {
            // Actual value (large) or em dash
            Text(actual.map { format($0) } ?? "—")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(actual != nil ? Color(.label) : Color(.tertiaryLabel))
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            // Label
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(.tertiaryLabel))
                .textCase(.uppercase)
                .kerning(0.3)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 5)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * progress, height: 5)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 5)

            // Target
            Text("/ \(format(target))")
                .font(.system(size: 10))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
