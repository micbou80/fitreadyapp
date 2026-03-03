import SwiftUI

/// Three always-visible daily stat cells (Steps / Calories / Protein)
/// plus a contextual protein tip that adapts to how close the user is to their goal.
struct CollapsedStatusSection: View {

    @ObservedObject var vm: TodayViewModel

    var body: some View {
        VStack(spacing: DS.Spacing.md) {

            // — Stat cells —
            HStack(spacing: 0) {
                statCell(
                    icon:      "figure.walk",
                    iconColor: Color(hex: "1B7D38"),
                    value:     formattedSteps,
                    label:     "steps"
                )
                separator
                statCell(
                    icon:      "fork.knife",
                    iconColor: Color(hex: "B45309"),
                    value:     formattedKcal,
                    label:     "/ \(vm.collapsedStats.nutrition.kcalTarget) kcal"
                )
                separator
                statCell(
                    icon:      "dumbbell.fill",
                    iconColor: .purple,
                    value:     formattedProtein,
                    label:     "protein"
                )
            }

            // — Protein tip (only once food has been logged) —
            if let tip = proteinTip {
                Divider()
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: tipIcon)
                        .font(.system(size: 11))
                        .foregroundStyle(tipIconColor)
                    Text(tip)
                        .font(DS.Typography.caption())
                        .foregroundStyle(Color(.secondaryLabel))
                    Spacer()
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Background.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
        .shadow(color: DS.Shadow.color, radius: DS.Shadow.radius, x: 0, y: DS.Shadow.y)
    }

    // MARK: - Stat cell

    @ViewBuilder
    private func statCell(icon: String, iconColor: Color, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(iconColor)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.75)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color(.secondaryLabel))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var separator: some View {
        Divider()
            .frame(height: 40)
    }

    // MARK: - Formatting

    private var formattedSteps: String {
        let s = vm.collapsedStats.steps
        return s >= 1_000 ? String(format: "%.1fk", Double(s) / 1_000) : "\(s)"
    }

    private var formattedKcal: String {
        let consumed = vm.collapsedStats.nutrition.kcalConsumed
        guard consumed > 0 else { return "—" }
        return consumed >= 1_000 ? String(format: "%.1fk", Double(consumed) / 1_000) : "\(consumed)"
    }

    private var formattedProtein: String {
        let n = vm.collapsedStats.nutrition
        guard n.proteinConsumed > 0 || n.proteinTarget > 0 else { return "—" }
        return "\(n.proteinConsumed) / \(n.proteinTarget)g"
    }

    // MARK: - Contextual protein tip

    private var proteinTip: String? {
        let n = vm.collapsedStats.nutrition
        guard n.proteinTarget > 0, n.proteinConsumed > 0 else { return nil }
        let rem = n.proteinRemaining
        switch rem {
        case ..<1:    return "Protein goal hit for today"
        case 1..<20:  return "Almost there — time to close the kitchen"
        case 20..<60: return "Find a high-protein snack to close the gap"
        default:      return "One more high-protein meal to go"
        }
    }

    private var tipIcon: String {
        (vm.collapsedStats.nutrition.proteinRemaining < 1) ? "checkmark.circle.fill" : "lightbulb.fill"
    }

    private var tipIconColor: Color {
        (vm.collapsedStats.nutrition.proteinRemaining < 1)
            ? Color(hex: "1B7D38")
            : Color(hex: "B45309")
    }
}
