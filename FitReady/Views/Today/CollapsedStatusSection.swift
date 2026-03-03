import SwiftUI

/// A row of StatusChips (steps, active kcal, protein remaining) that expands
/// inline to show full macro progress bars.
struct CollapsedStatusSection: View {

    @ObservedObject var vm: TodayViewModel
    @State private var expanded = false

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {

            // Chip row + expand toggle
            HStack(spacing: DS.Spacing.sm) {
                StatusChip(
                    icon:  "figure.walk",
                    value: formattedSteps,
                    color: Color(hex: "1B7D38")
                )
                StatusChip(
                    icon:  "flame.fill",
                    value: "\(vm.collapsedStats.activeKcal) kcal",
                    color: Color(hex: "EA580C")
                )
                StatusChip(
                    icon:  "fork.knife",
                    value: "\(vm.collapsedStats.proteinRemaining)g left",
                    color: .purple
                )

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        expanded.toggle()
                    }
                    Haptics.impact(.light)
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(.secondaryLabel))
                        .frame(width: 28, height: 28)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // Expanded macro bars
            if expanded {
                macroBarsView
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Background.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
        .shadow(color: DS.Shadow.color, radius: DS.Shadow.radius, x: 0, y: DS.Shadow.y)
    }

    // MARK: - Macro bars

    private var macroBarsView: some View {
        let n = vm.collapsedStats.nutrition
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Divider()
            macroBar(label: "Calories", current: n.kcalConsumed,    target: n.kcalTarget,    color: Color(hex: "7C3AED"))
            macroBar(label: "Protein",  current: n.proteinConsumed,  target: n.proteinTarget, color: Color(hex: "1B7D38"))
            macroBar(label: "Fat",      current: n.fatConsumed,      target: n.fatTarget,     color: Color(hex: "EA580C"))
            macroBar(label: "Carbs",    current: n.carbsConsumed,    target: n.carbsTarget,   color: Color(hex: "2563EB"))
        }
    }

    @ViewBuilder
    private func macroBar(label: String, current: Int, target: Int, color: Color) -> some View {
        let progress = min(1.0, Double(current) / Double(max(1, target)))
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(DS.Typography.caption())
                Spacer()
                Text("\(current) / \(target)")
                    .font(DS.Typography.caption())
                    .foregroundStyle(Color(.secondaryLabel))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * progress, height: 5)
                        .animation(.spring(response: 0.6), value: progress)
                }
            }
            .frame(height: 5)
        }
    }

    // MARK: - Helpers

    private var formattedSteps: String {
        let s = vm.collapsedStats.steps
        return s >= 1_000 ? String(format: "%.1fk", Double(s) / 1_000) : "\(s)"
    }
}
