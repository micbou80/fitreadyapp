import SwiftUI

/// Three always-visible daily stat cells (Steps / Calories / Protein)
/// each wrapped in a mini circular progress ring, plus a contextual protein tip.
struct CollapsedStatusSection: View {

    @ObservedObject var vm: TodayViewModel

    var body: some View {
        VStack(spacing: DS.Spacing.md) {

            // — Section label —
            Text("STEPS & NUTRITION")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
                .kerning(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)

            // — Stat cells with progress rings —
            HStack(spacing: 0) {
                ringCell(
                    icon:      "figure.walk",
                    iconColor: AppColors.greenBase,
                    progress:  stepProgress,
                    value:     formattedSteps,
                    label:     "steps",
                    hit:       vm.collapsedStats.steps >= vm.collapsedStats.stepGoal
                )
                separator
                ringCell(
                    icon:      "fork.knife",
                    iconColor: AppColors.metricActive,
                    progress:  kcalProgress,
                    value:     formattedKcal,
                    label:     "/ \(formattedKcalTarget) kcal",
                    hit:       kcalProgress >= 0.90
                )
                separator
                ringCell(
                    icon:      "🥚",
                    iconColor: AppColors.accent,
                    progress:  proteinProgress,
                    value:     formattedProteinConsumed,
                    label:     "/ \(formattedProteinTarget)g",
                    hit:       proteinProgress >= 0.90
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
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Background.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
        .shadow(color: DS.Shadow.color, radius: DS.Shadow.radius, x: 0, y: DS.Shadow.y)
    }

    // MARK: - Ring stat cell

    @ViewBuilder
    private func ringCell(
        icon:      String,
        iconColor: Color,
        progress:  Double,
        value:     String,
        label:     String,
        hit:       Bool = false
    ) -> some View {
        VStack(spacing: 6) {
            // Mini ring around icon
            ZStack {
                // Track
                Circle()
                    .stroke(AppColors.metricInactive, lineWidth: 3)
                    .frame(width: 38, height: 38)
                // Progress arc
                Circle()
                    .trim(from: 0, to: min(progress, 1))
                    .stroke(iconColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 38, height: 38)
                    .animation(.easeOut(duration: 0.6), value: progress)
                // Icon
                let isEmoji = icon.unicodeScalars.first.map { $0.value > 127 } ?? false
                if isEmoji {
                    Text(icon).font(.system(size: 15))
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if hit {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.greenText)
                        .background(Circle().fill(DS.Background.card).padding(-2))
                }
            }
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.75)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var separator: some View {
        Divider()
            .frame(height: 60)
    }

    // MARK: - Progress values

    private var stepProgress: Double {
        let n = vm.collapsedStats
        return min(1.0, Double(n.steps) / Double(max(1, n.stepGoal)))
    }

    private var kcalProgress: Double {
        let n = vm.collapsedStats.nutrition
        guard n.kcalTarget > 0 else { return 0 }
        return min(1.0, Double(n.kcalConsumed) / Double(n.kcalTarget))
    }

    private var proteinProgress: Double {
        let n = vm.collapsedStats.nutrition
        guard n.proteinTarget > 0 else { return 0 }
        return min(1.0, Double(n.proteinConsumed) / Double(n.proteinTarget))
    }

    // MARK: - Formatting

    private var formattedSteps: String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        return fmt.string(from: NSNumber(value: vm.collapsedStats.steps)) ?? "\(vm.collapsedStats.steps)"
    }

    private var formattedKcal: String {
        let consumed = vm.collapsedStats.nutrition.kcalConsumed
        guard consumed > 0 else { return "—" }
        let fmt = NumberFormatter(); fmt.numberStyle = .decimal
        return fmt.string(from: NSNumber(value: consumed)) ?? "\(consumed)"
    }

    private var formattedKcalTarget: String {
        let fmt = NumberFormatter(); fmt.numberStyle = .decimal
        let target = vm.collapsedStats.nutrition.kcalTarget
        return fmt.string(from: NSNumber(value: target)) ?? "\(target)"
    }

    private var formattedProteinConsumed: String {
        let consumed = vm.collapsedStats.nutrition.proteinConsumed
        guard consumed > 0 else { return "—" }
        return "\(consumed)g"
    }

    private var formattedProteinTarget: String {
        "\(vm.collapsedStats.nutrition.proteinTarget)"
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
            ? AppColors.greenText
            : AppColors.amberText
    }
}
