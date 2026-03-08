import SwiftUI
import UIKit

// MARK: - Workout data

private struct ExerciseDef {
    let name:  String
    let cue:   String
    let steps: [String]
}

private let exerciseDefs: [ExerciseDef] = [
    .init(
        name:  "Crocodile Breathing",
        cue:   "Belly expands into floor on each inhale",
        steps: [
            "Lie face-down, forehead resting on your hands.",
            "Inhale slowly through your nose — feel your belly push into the floor.",
            "Exhale fully, letting your belly fall back. Repeat at a steady 4-second pace."
        ]
    ),
    .init(
        name:  "90/90 Hip Rotations",
        cue:   "Hips level — rotate deliberately each side",
        steps: [
            "Sit on the floor with both knees bent at 90°, one in front, one to the side.",
            "Keeping hips level, rotate both knees to the opposite side in one smooth movement.",
            "Pause for 2 seconds at each end range. Keep your torso upright throughout."
        ]
    ),
    .init(
        name:  "World's Greatest Stretch",
        cue:   "Deep lunge, rotate open, reach tall",
        steps: [
            "Step into a deep lunge with your right foot forward, left knee hovering off the ground.",
            "Place your right hand inside your front foot; rotate your left arm up toward the ceiling.",
            "Follow your hand with your eyes. Hold 2s, lower, repeat — then switch sides."
        ]
    ),
    .init(
        name:  "Cat–Cow",
        cue:   "Round up on exhale, arch gently on inhale",
        steps: [
            "Start on all fours, wrists under shoulders, knees under hips.",
            "Exhale and round your spine toward the ceiling, tucking chin and tailbone (Cat).",
            "Inhale and let your belly drop, lifting your head and tailbone gently (Cow). Flow smoothly."
        ]
    ),
    .init(
        name:  "Kneeling Hip Flexor Rock + Reach",
        cue:   "Rock back, then reach forward and up",
        steps: [
            "Kneel on your left knee, right foot forward in a lunge position.",
            "Rock your hips backward toward your heel to stretch the hip flexor.",
            "Then drive forward and reach your left arm overhead. Alternate rock and reach for the full 60s, then switch sides."
        ]
    ),
    .init(
        name:  "Standing Hamstring Sweep",
        cue:   "Hinge at hip, soft knee, feel the pull",
        steps: [
            "Stand tall, feet hip-width apart. Soften your knees slightly.",
            "Hinge forward from your hips — not your waist — letting arms hang toward the floor.",
            "Slowly sweep back up one vertebra at a time. Feel the hamstrings lengthen at the bottom of each rep."
        ]
    ),
    .init(
        name:  "Ankle Knee-to-Wall Mobilization",
        cue:   "Heel down, drive knee gently past toes",
        steps: [
            "Stand facing a wall, right foot about 10 cm away, hands touching wall lightly.",
            "Drive your right knee forward toward the wall, keeping your heel flat on the floor.",
            "Move your foot back until heel just lifts, then inch it forward and retry. Switch sides halfway."
        ]
    ),
]

private struct WorkoutStep: Identifiable {
    let id: Int
    let isExercise:    Bool
    let exerciseIndex: Int?   // nil for rest steps
    let duration:      Int    // seconds
}

private let allSteps: [WorkoutStep] = {
    var arr = [WorkoutStep]()
    for i in 0..<exerciseDefs.count {
        arr.append(WorkoutStep(id: arr.count, isExercise: true,  exerciseIndex: i,    duration: 60))
        if i < exerciseDefs.count - 1 {
            arr.append(WorkoutStep(id: arr.count, isExercise: false, exerciseIndex: nil, duration: 10))
        }
    }
    return arr
}()

// File-level timer to avoid publisher recreation on every re-render
private let workoutTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

// MARK: - View

struct RecoveryWorkoutView: View {

    enum Phase { case preview, countdown, active, done }

    @Environment(\.dismiss) private var dismiss
    @State private var phase:            Phase = .preview
    @State private var countdownSeconds: Int   = 5
    @State private var stepIndex:        Int   = 0
    @State private var secondsLeft:      Int   = allSteps[0].duration
    @State private var totalElapsed:     Int   = 0
    @State private var showExitAlert:    Bool  = false

    // MARK: - Body

    var body: some View {
        ZStack {
            DS.Background.page.ignoresSafeArea()
            switch phase {
            case .preview:   previewScreen
            case .countdown: countdownScreen
            case .active:    activeScreen
            case .done:      doneScreen
            }
        }
        .onReceive(workoutTicker) { _ in
            switch phase {
            case .countdown:
                tickCountdown()
            case .active:
                tick()
            default:
                break
            }
        }
        .onChange(of: phase) { _, newPhase in
            switch newPhase {
            case .countdown, .active:
                UIApplication.shared.isIdleTimerDisabled = true
            case .done, .preview:
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .confirmationDialog(
            "Stop workout?",
            isPresented: $showExitAlert,
            titleVisibility: .visible
        ) {
            Button("Stop & Exit", role: .destructive) { dismiss() }
            Button("Keep Going",  role: .cancel) {}
        } message: {
            Text("Your progress will be lost.")
        }
    }

    // MARK: - Preview screen

    private var previewScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Top bar
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(AppColors.textMuted)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)

                // Hero
                VStack(spacing: DS.Spacing.md) {
                    Image(systemName: "figure.flexibility")
                        .font(.system(size: 44))
                        .foregroundStyle(AppColors.accent)
                        .frame(width: 76, height: 76)
                        .background(AppColors.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 20))

                    Text("Quick Mobility")
                        .font(.system(size: 26, weight: .bold, design: .rounded))

                    HStack(spacing: DS.Spacing.lg) {
                        Label("7 exercises", systemImage: "list.bullet")
                        Label("~8 min",      systemImage: "clock")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)

                    Text("Gentle movement for joints and muscles.\nFollow along — we'll guide each step.")
                        .font(DS.Typography.body())
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.sm)

                // Start button
                Button(action: startWorkout) {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "play.fill")
                        Text("Start Now")
                    }
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColors.textOnBrand)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColors.brandPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Corner.button))
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.xl)

                // Exercise list
                Text("WHAT'S AHEAD")
                    .font(DS.Typography.label())
                    .foregroundStyle(AppColors.textSecondary)
                    .kerning(0.5)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.xl)
                    .padding(.bottom, DS.Spacing.md)

                VStack(spacing: 0) {
                    ForEach(Array(exerciseDefs.enumerated()), id: \.offset) { i, ex in
                        HStack(alignment: .top, spacing: DS.Spacing.md) {
                            Text("\(i + 1)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.accent)
                                .frame(width: 26, height: 26)
                                .background(AppColors.accent.opacity(0.10))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(ex.name)
                                    .font(DS.Typography.body())
                                Text(ex.cue)
                                    .font(DS.Typography.caption())
                                    .foregroundStyle(AppColors.textSecondary)
                            }

                            Spacer()

                            Text("60s")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(AppColors.textMuted)
                                .padding(.top, 4)
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.md)

                        if i < exerciseDefs.count - 1 {
                            HStack(spacing: DS.Spacing.md) {
                                Capsule()
                                    .fill(AppColors.border)
                                    .frame(width: 2, height: 18)
                                    .frame(width: 26, alignment: .center)
                                Text("Rest  ·  10s")
                                    .font(DS.Typography.caption())
                                    .foregroundStyle(AppColors.textMuted)
                            }
                            .padding(.horizontal, DS.Spacing.lg)
                        }
                    }
                }

                Spacer(minLength: DS.Spacing.xl)
            }
        }
    }

    // MARK: - Countdown screen

    private var countdownScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: DS.Spacing.lg) {
                Text("GET READY")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.textSecondary)
                    .tracking(2)

                Text("\(countdownSeconds)")
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppColors.accent)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.spring(response: 0.3), value: countdownSeconds)

                VStack(spacing: DS.Spacing.xs) {
                    Text("First up")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textMuted)
                    Text(exerciseDefs[0].name)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
            .frame(maxWidth: .infinity)

            Spacer()

            Button { showExitAlert = true } label: {
                Text("Cancel")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.bottom, DS.Spacing.xl)
        }
    }

    // MARK: - Active screen

    private var activeScreen: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {

                // Fixed header
                HStack(spacing: DS.Spacing.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quick Mobility")
                            .font(.system(size: 15, weight: .semibold))
                        Text(progressText)
                            .font(DS.Typography.caption())
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    Spacer()
                    Button { showExitAlert = true } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(AppColors.textMuted)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(AppColors.metricInactive)
                        Rectangle()
                            .fill(AppColors.accent)
                            .frame(width: geo.size.width * progressFraction)
                            .animation(.linear(duration: 1), value: totalElapsed)
                    }
                }
                .frame(height: 3)

                Divider()

                // Scrollable timeline
                ScrollView {
                    timelineView
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.top, DS.Spacing.lg)
                        .padding(.bottom, 80)
                }
            }
            .onChange(of: stepIndex) { _, newIdx in
                withAnimation(.spring(response: 0.45)) {
                    proxy.scrollTo("step_\(newIdx)", anchor: .center)
                }
            }
        }
    }

    // MARK: - Done screen

    private var doneScreen: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 60)

                VStack(spacing: DS.Spacing.xl) {
                    ZStack {
                        Circle()
                            .fill(AppColors.greenSoft)
                            .frame(width: 96, height: 96)
                        Image(systemName: "checkmark")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(AppColors.greenText)
                    }

                    VStack(spacing: DS.Spacing.sm) {
                        Text("Done.")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                        Text("All 7 exercises complete.\nYou showed up — that's what matters.")
                            .font(DS.Typography.body())
                            .foregroundStyle(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    // Exercise recap
                    VStack(spacing: DS.Spacing.sm) {
                        ForEach(Array(exerciseDefs.enumerated()), id: \.offset) { _, ex in
                            HStack(spacing: DS.Spacing.sm) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppColors.greenText)
                                Text(ex.name)
                                    .font(DS.Typography.caption())
                                    .foregroundStyle(AppColors.textSecondary)
                                Spacer()
                            }
                        }
                    }
                    .padding(DS.Spacing.lg)
                    .background(DS.Background.card)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
                    .shadow(color: DS.Shadow.color, radius: DS.Shadow.radius, x: 0, y: DS.Shadow.y)
                }
                .padding(.horizontal, DS.Spacing.lg)

                Spacer(minLength: 60)

                Button { dismiss() } label: {
                    Text("Back to Today")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.textOnBrand)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                        .background(AppColors.brandPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Corner.button))
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xl)
            }
        }
    }

    // MARK: - Timeline

    private var timelineView: some View {
        VStack(spacing: 0) {
            ForEach(allSteps) { step in
                let isActive  = step.id == stepIndex
                let isDone    = step.id < stepIndex
                let isLast    = step.id == allSteps.count - 1

                if step.isExercise, let exIdx = step.exerciseIndex {
                    exerciseRow(
                        step:     step,
                        exIdx:    exIdx,
                        isActive: isActive,
                        isDone:   isDone,
                        isLast:   isLast
                    )
                } else {
                    restRow(step: step, isActive: isActive, isDone: isDone)
                }
            }
        }
    }

    // MARK: - Exercise row

    @ViewBuilder
    private func exerciseRow(
        step: WorkoutStep, exIdx: Int,
        isActive: Bool, isDone: Bool, isLast: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {

            // Left column: dot + short connector
            VStack(spacing: 0) {
                // Dot
                ZStack {
                    Circle()
                        .fill(
                            isDone   ? AppColors.greenText :
                            isActive ? AppColors.accent    :
                                       AppColors.border
                        )
                        .frame(width: 24, height: 24)

                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppColors.textOnBrand)
                    } else {
                        Text("\(exIdx + 1)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(isActive ? AppColors.textOnBrand : AppColors.textSecondary)
                    }
                }
                // Short connector flowing into the rest row below
                if !isLast {
                    Rectangle()
                        .fill(isDone ? AppColors.greenText.opacity(0.35) : AppColors.border.opacity(0.5))
                        .frame(width: 2, height: 12)
                }
            }
            .frame(width: 24, alignment: .top)

            // Right: card
            Group {
                if isActive {
                    activeExCard(ex: exerciseDefs[exIdx], secsLeft: secondsLeft)
                } else if isDone {
                    doneExCard(ex: exerciseDefs[exIdx])
                } else {
                    upcomingExCard(ex: exerciseDefs[exIdx])
                }
            }
            .padding(.bottom, isLast ? DS.Spacing.sm : 0)
        }
        .id("step_\(step.id)")
    }

    // Active exercise card — large with prominent countdown and step-by-step instructions
    private func activeExCard(ex: ExerciseDef, secsLeft: Int) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(ex.name)
                .font(DS.Typography.title())

            // Step-by-step bullets
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                ForEach(Array(ex.steps.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top, spacing: DS.Spacing.xs) {
                        Text("\(i + 1).")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.accent)
                            .frame(width: 18, alignment: .leading)
                        Text(step)
                            .font(DS.Typography.caption())
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            HStack {
                Spacer()
                VStack(spacing: 3) {
                    Text("\(secsLeft)")
                        .font(.system(size: 62, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(AppColors.accent)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.linear(duration: 0.15), value: secsLeft)
                    Text("seconds left")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
            }
            .padding(.vertical, DS.Spacing.sm)
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.accent.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Corner.card)
                .strokeBorder(AppColors.accent.opacity(0.22), lineWidth: 1.5)
        )
        .padding(.bottom, DS.Spacing.md)
    }

    // Completed exercise card — compact, ticked
    private func doneExCard(ex: ExerciseDef) -> some View {
        HStack {
            Text(ex.name)
                .font(DS.Typography.body())
                .foregroundStyle(AppColors.textMuted)
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(AppColors.greenText)
        }
        .padding(.vertical, DS.Spacing.sm)
        .padding(.horizontal, DS.Spacing.xs)
        .padding(.bottom, 4)
    }

    // Upcoming exercise card — readable but not active
    private func upcomingExCard(ex: ExerciseDef) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ex.name)
                    .font(DS.Typography.body())
                Text(ex.cue)
                    .font(DS.Typography.caption())
                    .foregroundStyle(AppColors.textMuted)
            }
            Spacer()
            Text("60s")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(AppColors.textMuted)
                .padding(.top, 2)
        }
        .padding(.vertical, DS.Spacing.sm)
        .padding(.horizontal, DS.Spacing.xs)
        .padding(.bottom, 4)
    }

    // MARK: - Rest row

    @ViewBuilder
    private func restRow(step: WorkoutStep, isActive: Bool, isDone: Bool) -> some View {
        HStack(alignment: .center, spacing: 14) {

            // Left column: line-dot-line
            VStack(spacing: 0) {
                Rectangle()
                    .fill(isDone ? AppColors.greenText.opacity(0.35) : AppColors.border.opacity(0.5))
                    .frame(width: 2, height: 10)
                Circle()
                    .fill(
                        isActive ? AppColors.amberBase :
                        isDone   ? AppColors.greenText.opacity(0.5) :
                                   AppColors.border
                    )
                    .frame(width: 8, height: 8)
                Rectangle()
                    .fill(isDone ? AppColors.greenText.opacity(0.35) : AppColors.border.opacity(0.5))
                    .frame(width: 2, height: 10)
            }
            .frame(width: 24, alignment: .center)

            // Right: rest label / active countdown
            if isActive {
                HStack(spacing: DS.Spacing.sm) {
                    Text("REST")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppColors.amberText)
                        .tracking(0.5)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, 4)
                        .background(AppColors.amberSoft)
                        .clipShape(Capsule())

                    Text("\(secondsLeft)s")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(AppColors.amberText)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.linear(duration: 0.15), value: secondsLeft)
                }
            } else {
                Text(isDone ? "Rest" : "Rest  ·  10s")
                    .font(DS.Typography.caption())
                    .foregroundStyle(AppColors.textMuted)
            }
        }
        .padding(.vertical, 2)
        .id("step_\(step.id)")
    }

    // MARK: - Computed helpers

    private var progressFraction: Double {
        let total = allSteps.reduce(0) { $0 + $1.duration }
        return total > 0 ? min(1.0, Double(totalElapsed) / Double(total)) : 0
    }

    private var progressText: String {
        let done = allSteps.prefix(stepIndex).filter { $0.isExercise }.count
        return "\(done) of \(exerciseDefs.count) exercises"
    }

    // MARK: - Timer logic

    private func startWorkout() {
        stepIndex        = 0
        secondsLeft      = allSteps[0].duration
        totalElapsed     = 0
        countdownSeconds = 5
        phase            = .countdown
        Haptics.impact(.medium)
    }

    private func tickCountdown() {
        if countdownSeconds > 1 {
            countdownSeconds -= 1
            Haptics.impact(.light)
        } else {
            phase = .active
            Haptics.impact(.medium)
        }
    }

    private func tick() {
        totalElapsed += 1

        // Haptic pulse every 60 seconds of total workout time
        if totalElapsed % 60 == 0 {
            Haptics.notification(.success)
        }

        if secondsLeft > 1 {
            secondsLeft -= 1
        } else {
            advanceStep()
        }
    }

    private func advanceStep() {
        let nextIdx = stepIndex + 1
        if nextIdx < allSteps.count {
            stepIndex   = nextIdx
            secondsLeft = allSteps[nextIdx].duration
            Haptics.impact(.light)
        } else {
            phase = .done
            Haptics.notification(.success)
        }
    }
}
