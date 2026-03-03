import SwiftUI

/// Hero card: state label, headline, reassurance, one-line reason, "See details" link.
/// No large ring — state is communicated through colour + words.
struct TodayHeroSection: View {

    @ObservedObject var vm: TodayViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {

            // Accessibility state label (small chip)
            Text(vm.readinessState.accessibilityLabel.uppercased())
                .font(DS.Typography.label())
                .foregroundStyle(DS.StateColor.primary(for: vm.readinessState))
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, 3)
                .background(DS.StateColor.primary(for: vm.readinessState).opacity(0.12))
                .clipShape(Capsule())

            // Headline
            Text(headlineText)
                .font(DS.Typography.hero())
                .foregroundStyle(Color(.label))

            // Reassurance
            Text(reassuranceText)
                .font(DS.Typography.body())
                .foregroundStyle(Color(.secondaryLabel))

            // Reason (muted, one line)
            if !vm.readinessReason.isEmpty {
                Text(vm.readinessReason)
                    .font(DS.Typography.caption())
                    .foregroundStyle(Color(.tertiaryLabel))
            }

            // See details
            Button {
                vm.detailsSheetVisible = true
                Haptics.impact(.light)
            } label: {
                HStack(spacing: 3) {
                    Text("See details")
                    Image(systemName: "chevron.right")
                }
                .font(DS.Typography.caption().weight(.semibold))
                .foregroundStyle(DS.StateColor.primary(for: vm.readinessState))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Corner.card)
                .fill(DS.StateColor.background(for: vm.readinessState))
        )
    }

    private var headlineText: String {
        switch vm.readinessState {
        case .green:  return "You're ready.\nGo make it count."
        case .yellow: return "Go lighter today."
        case .red:    return "Rest and recover."
        }
    }

    private var reassuranceText: String {
        switch vm.readinessState {
        case .green:  return "Body primed, schedule clear. Push hard."
        case .yellow: return "Lighter days are how progress sticks."
        case .red:    return "Recovery is when you actually get stronger."
        }
    }
}
