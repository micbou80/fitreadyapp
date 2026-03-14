import SwiftUI

/// Completion card shown immediately after a workout is saved.
/// Displays sets done, estimated kcal burned, duration, and any progression highlights.
struct WorkoutSummarySheet: View {

    let session: WorkoutSession
    let program: WorkoutProgram

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var healthKit: HealthKitManager

    // MARK: - Derived

    /// Total completed sets across all exercises.
    private var totalSets: Int {
        session.exercises.reduce(0) { $0 + $1.sets.count }
    }

    /// Duration formatted as "m:ss" or "h:mm".
    private var durationLabel: String {
        let s = session.durationSeconds
        if s >= 3600 {
            return String(format: "%d:%02d h", s / 3600, (s % 3600) / 60)
        }
        return String(format: "%d min", s / 60)
    }

    /// Rough estimated kcal burned.
    /// Formula: MET × body-weight × hours.
    /// MET ≈ 4.5–6.5 for moderate weightlifting, 7.0–9.0 for running.
    /// Uses the most recent weight from HealthKit, falling back to 75 kg if unavailable.
    private var estimatedKcalRange: String {
        let hours      = Double(session.durationSeconds) / 3600.0
        let weightKg   = healthKit.currentWeightKg ?? 75.0
        let isRun      = program.planType == .run
        let metLow: Double  = isRun ? 7.0 : 4.5
        let metHigh: Double = isRun ? 9.0 : 6.5
        let low  = Int(metLow  * weightKg * hours)
        let high = Int(metHigh * weightKg * hours)
        return "\(low)–\(high) kcal"
    }

    /// Whether we fell back to the default weight because HealthKit had no value.
    private var usingDefaultWeight: Bool { healthKit.currentWeightKg == nil }

    /// Progression badges: exercises where the user achieved a new set/rep target or weight.
    private var progressionHighlights: [String] {
        var items: [String] = []
        for ex in session.exercises {
            guard !ex.sets.isEmpty, let template = program.exercises.first(where: { $0.name == ex.name }) else { continue }
            if ex.type == .weighted {
                let maxW = ex.sets.map(\.weight).max() ?? 0
                if maxW > template.defaultWeight {
                    items.append("\(ex.name): \(ProgressionEngine.fmtW(maxW)) kg")
                }
            }
        }
        return Array(items.prefix(3))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DS.Spacing.xl) {

                        // MARK: Header
                        VStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 52, weight: .medium))
                                .foregroundStyle(AppColors.brandPrimary)

                            Text("Workout complete")
                                .font(DS.Typography.hero())
                                .foregroundStyle(AppColors.textPrimary)
                                .multilineTextAlignment(.center)

                            Text("That's another one in the bank.")
                                .font(DS.Typography.body())
                                .foregroundStyle(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, DS.Spacing.xl)

                        // MARK: Stats card
                        VStack(spacing: 0) {
                            statRow(
                                icon: "timer",
                                color: AppColors.info,
                                label: "Duration",
                                value: durationLabel
                            )
                            Divider().padding(.horizontal, DS.Spacing.md)
                            statRow(
                                icon: "dumbbell.fill",
                                color: AppColors.brandForeground,
                                label: "Sets completed",
                                value: "\(totalSets)"
                            )
                            Divider().padding(.horizontal, DS.Spacing.md)
                            statRow(
                                icon: "flame.fill",
                                color: AppColors.dataCalories,
                                label: "Est. energy burned",
                                value: estimatedKcalRange
                            )
                        }
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
                        .overlay(RoundedRectangle(cornerRadius: DS.Corner.card).strokeBorder(DS.Border.color, lineWidth: 1))
                        .shadow(color: DS.Shadow.color, radius: DS.Shadow.radius, y: DS.Shadow.y)

                        // MARK: Progression highlights
                        if !progressionHighlights.isEmpty {
                            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                                Text("PROGRESSION")
                                    .font(DS.Typography.label())
                                    .foregroundStyle(AppColors.textSecondary)
                                    .kerning(0.5)

                                VStack(spacing: DS.Spacing.xs) {
                                    ForEach(progressionHighlights, id: \.self) { item in
                                        HStack(spacing: DS.Spacing.sm) {
                                            Image(systemName: "arrow.up.circle.fill")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(AppColors.brandPrimary)
                                            Text(item)
                                                .font(DS.Typography.body())
                                                .foregroundStyle(AppColors.textPrimary)
                                            Spacer()
                                        }
                                        .padding(.horizontal, DS.Spacing.md)
                                        .padding(.vertical, DS.Spacing.sm)
                                        .background(.ultraThinMaterial)
                                        .clipShape(RoundedRectangle(cornerRadius: DS.Corner.chip))
                                        .overlay(RoundedRectangle(cornerRadius: DS.Corner.chip).strokeBorder(DS.Border.color, lineWidth: 1))
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // MARK: Calorie note
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 13))
                                .foregroundStyle(AppColors.textMuted)
                            Text(usingDefaultWeight
                                 ? "Energy estimate uses a 75 kg baseline (no weight found in Health). Log this workout in Apple Fitness for a personalised figure."
                                 : "Energy estimate based on your current weight from Health. Log this workout in Apple Fitness for a more precise figure.")
                                .font(DS.Typography.caption())
                                .foregroundStyle(AppColors.textMuted)
                        }
                        .padding(.horizontal, DS.Spacing.sm)

                        // MARK: CTA
                        Button { dismiss() } label: {
                            HStack(spacing: DS.Spacing.xs) {
                                Spacer()
                                Text("DONE")
                                    .font(.system(size: 15, weight: .heavy))
                                    .kerning(-0.3)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .bold))
                                Spacer()
                            }
                            .foregroundStyle(AppColors.textOnBrand)
                            .padding(.vertical, DS.Spacing.md)
                            .background(AppColors.brandPrimary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, DS.Spacing.xl)
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(AppColors.surface)
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    // MARK: - Stat row

    @ViewBuilder
    private func statRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(label)
                .font(DS.Typography.body())
                .foregroundStyle(AppColors.textPrimary)

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
    }
}

// MARK: - Preview

#Preview {
    let session = WorkoutSession(
        date: Date(),
        durationSeconds: 2700,
        exercises: [
            ExerciseRecord(
                name: "Machine Chest Press",
                type: .weighted,
                sets: [
                    SetRecord(weight: 55, reps: 12),
                    SetRecord(weight: 55, reps: 10),
                    SetRecord(weight: 52.5, reps: 9)
                ]
            ),
            ExerciseRecord(
                name: "Lat Pulldown",
                type: .weighted,
                sets: [SetRecord(weight: 52.5, reps: 10), SetRecord(weight: 50, reps: 10)]
            )
        ]
    )
    WorkoutSummarySheet(session: session, program: .pushDay)
        .environmentObject(HealthKitManager())
        .preferredColorScheme(.dark)
}
