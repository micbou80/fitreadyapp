import SwiftUI

/// Horizontal swipe carousel of quick recovery exercises.
/// Cards: Breathe (live) · Quick Mobility (live) · Cold Splash (coming soon) · Focus Sound (coming soon)
struct RecoveryCarouselSection: View {

    @State private var showingBreathing = false
    @State private var showingMobility  = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {

            Text("QUICK RECOVERY")
                .font(DS.Typography.label())
                .foregroundStyle(AppColors.textSecondary)
                .kerning(0.5)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.md) {

                    // — Breathe —
                    recoveryCard(
                        icon:     "wind",
                        color:    AppColors.brandPrimary,
                        title:    "Breathe",
                        duration: "5 min",
                        detail:   "3s in · 4s out",
                        locked:   false
                    ) {
                        showingBreathing = true
                        Haptics.impact(.light)
                    }

                    // — Quick Mobility —
                    recoveryCard(
                        icon:     "figure.flexibility",
                        color:    AppColors.brandPrimary,
                        title:    "Quick Mobility",
                        duration: "~8 min",
                        detail:   "7 exercises",
                        locked:   false
                    ) {
                        showingMobility = true
                        Haptics.impact(.light)
                    }

                    // — Cold Splash (coming soon) —
                    recoveryCard(
                        icon:     "thermometer.snowflake",
                        color:    AppColors.dataSleep,
                        title:    "Cold Splash",
                        duration: "2 min",
                        detail:   "Coming soon",
                        locked:   true
                    ) {}

                    // — Focus Sound (coming soon) —
                    recoveryCard(
                        icon:     "ear.fill",
                        color:    AppColors.dataCalories,
                        title:    "Focus Sound",
                        duration: "10 min",
                        detail:   "Coming soon",
                        locked:   true
                    ) {}
                }
                .padding(.vertical, 4) // let shadows breathe
            }
        }
        .fullScreenCover(isPresented: $showingBreathing) {
            BreathingExerciseView()
        }
        .fullScreenCover(isPresented: $showingMobility) {
            RecoveryWorkoutView()
        }
    }

    // MARK: - Card builder

    @ViewBuilder
    private func recoveryCard(
        icon:     String,
        color:    Color,
        title:    String,
        duration: String,
        detail:   String,
        locked:   Bool,
        action:   @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {

                // Icon area
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(locked ? color.opacity(0.06) : AppColors.brandMuted)
                        .frame(width: 44, height: 44)
                    Image(systemName: locked ? "lock.fill" : icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(locked ? AppColors.textMuted : color)
                }

                Spacer(minLength: 0)

                // Title
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(locked ? AppColors.textMuted : AppColors.textPrimary)
                    .lineLimit(1)

                // Duration + detail
                VStack(alignment: .leading, spacing: 2) {
                    Text(duration)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(locked ? AppColors.textMuted : color)
                    Text(detail)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(AppColors.textMuted)
                }
            }
            .padding(DS.Spacing.md)
            .frame(width: 130, height: 140, alignment: .topLeading)
            .background(DS.Background.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
            .shadow(color: DS.Shadow.color, radius: DS.Shadow.radius, x: 0, y: DS.Shadow.y)
            .opacity(locked ? 0.70 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(locked)
    }
}
