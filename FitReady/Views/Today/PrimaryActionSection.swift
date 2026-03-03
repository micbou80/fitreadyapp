import SwiftUI

/// The single most important action card for the day.
/// Shows title + duration, 1–2 focus bullets, and the primary CTA.
/// Transitions to a "Done" state after the user taps the CTA.
struct PrimaryActionSection: View {

    @ObservedObject var vm: TodayViewModel

    var body: some View {
        SoftCard {
            if vm.actionCompleted {
                completedView
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            } else {
                actionView
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: vm.actionCompleted)
    }

    // MARK: - Action view

    private var actionView: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {

            // Header: title + duration badge
            HStack(alignment: .firstTextBaseline) {
                Text(vm.recommendedAction.title)
                    .font(DS.Typography.title())
                Spacer()
                Text(vm.recommendedAction.duration)
                    .font(DS.Typography.caption())
                    .foregroundStyle(Color(.secondaryLabel))
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 3)
                    .background(AppColors.background)
                    .clipShape(Capsule())
            }

            Divider()

            // Focus bullets
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                ForEach(vm.recommendedAction.bullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: DS.Spacing.sm) {
                        Circle()
                            .fill(DS.StateColor.primary(for: vm.readinessState))
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)
                        Text(bullet)
                            .font(DS.Typography.body())
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
            }

            PrimaryCTAButton(
                label:  vm.recommendedAction.ctaLabel,
                state:  vm.readinessState,
                action: { vm.completeAction() }
            )
            .padding(.top, DS.Spacing.xs)
        }
    }

    // MARK: - Completed view

    private var completedView: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(AppColors.greenText)
                Text(vm.recommendedAction.completedMessage)
                    .font(DS.Typography.title())
            }
            Text(vm.recommendedAction.nextSuggestion)
                .font(DS.Typography.body())
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
