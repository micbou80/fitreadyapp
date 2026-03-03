import SwiftUI

/// Up to 2 secondary action cards shown as a horizontal pair.
struct SecondaryActionsSection: View {

    @ObservedObject var vm: TodayViewModel

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            ForEach(vm.secondaryActions) { action in
                secondaryCard(action)
            }
        }
    }

    @ViewBuilder
    private func secondaryCard(_ action: SecondaryAction) -> some View {
        Button {
            Haptics.impact(.light)
        } label: {
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: action.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(.purple)
                    .frame(width: 46, height: 46)
                    .background(Color.purple.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(action.label)
                    .font(DS.Typography.caption())
                    .foregroundStyle(Color(.label))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(DS.Spacing.md)
            .background(DS.Background.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
            .shadow(color: DS.Shadow.color, radius: DS.Shadow.radius, x: 0, y: DS.Shadow.y)
        }
        .buttonStyle(.plain)
    }
}
