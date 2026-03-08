import SwiftUI

/// Compact card that gives fast access to the 7-minute recovery session.
/// Shown on every Today screen; tapping the button launches RecoveryWorkoutView.
struct QuickRecoveryCard: View {

    let action: () -> Void

    var body: some View {
        SoftCard {
            HStack(spacing: DS.Spacing.md) {

                // Icon
                Image(systemName: "figure.flexibility")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppColors.greenBase)
                    .frame(width: 44, height: 44)
                    .background(AppColors.greenBase.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                // Copy
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quick Recovery")
                        .font(DS.Typography.body().weight(.semibold))
                    Text("7 min · mobility + breathing")
                        .font(DS.Typography.caption())
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                // CTA
                Button(action: action) {
                    Text("Start")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.textOnBrand)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(AppColors.metricActive)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    QuickRecoveryCard { }
        .padding()
}
