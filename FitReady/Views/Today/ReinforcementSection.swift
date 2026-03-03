import SwiftUI

/// Supportive, non-judgmental momentum summary + win message.
struct ReinforcementSection: View {

    @ObservedObject var vm: TodayViewModel

    private var progress: Double {
        Double(vm.momentum.onTrackDays) / Double(max(1, vm.momentum.targetDays))
    }

    var body: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {

                // Momentum row
                HStack(spacing: DS.Spacing.md) {
                    MiniRing(progress: progress, color: .purple)
                        .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.momentum.message)
                            .font(DS.Typography.body())
                        Text("Keep it going")
                            .font(DS.Typography.caption())
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }

                // Win message
                if let win = vm.winMessage {
                    Divider()
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "F59E0B"))
                        Text(win)
                            .font(DS.Typography.caption())
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
            }
        }
    }
}
