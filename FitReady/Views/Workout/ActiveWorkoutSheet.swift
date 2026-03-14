import SwiftUI

// MARK: - Sheet

struct ActiveWorkoutSheet: View {

    var program: WorkoutProgram = .pushDay
    var onComplete: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var liveSets: [[LiveSet]] = []
    @State private var startDate = Date()
    @State private var elapsed = 0
    @State private var showFinish = false
    @State private var lastSession: WorkoutSession? = nil
    @State private var completedSession: WorkoutSession? = nil

    private var exercises: [ExerciseTemplate] { program.exercises }
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Background.page.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: DS.Spacing.lg) {

                        timerCard

                        ForEach(exercises.indices, id: \.self) { i in
                            if i < liveSets.count {
                                ExerciseCard(
                                    exercise: exercises[i],
                                    hint: ProgressionEngine.hint(for: exercises[i], last: lastSession),
                                    sets: $liveSets[i],
                                    onAddSet: {
                                        let last = liveSets[i].last
                                        let newSet = LiveSet(
                                            weight: last?.weight ?? exercises[i].defaultWeight,
                                            reps:   last?.reps   ?? exercises[i].defaultReps
                                        )
                                        withAnimation(.spring(duration: 0.25)) {
                                            liveSets[i].append(newSet)
                                        }
                                        Haptics.impact(.light)
                                    },
                                    onRemoveSet: {
                                        guard liveSets[i].count > 1 else { return }
                                        withAnimation(.spring(duration: 0.25)) {
                                            liveSets[i].removeLast()
                                        }
                                        Haptics.impact(.light)
                                    }
                                )
                            }
                        }

                        finishButton
                            .padding(.bottom, DS.Spacing.xl)
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.md)
                }
            }
            .navigationTitle(program.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppColors.textSecondary)
                }
                // Global Done button for any active weight/reps text field
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                lastSession = WorkoutStore.lastSession(for: program)
                startDate = Date()
                elapsed = 0
                initSets()
            }
            // Tick every second to update display while app is visible
            .onReceive(timer) { _ in
                elapsed = Int(Date().timeIntervalSince(startDate))
            }
            // Recompute when returning from background / lock screen
            .onReceive(
                NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            ) { _ in
                elapsed = Int(Date().timeIntervalSince(startDate))
            }
            .confirmationDialog("Finish workout?", isPresented: $showFinish, titleVisibility: .visible) {
                Button("Save & Finish") { saveAndFinish() }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(item: $completedSession) { session in
                WorkoutSummarySheet(session: session, program: program)
            }
        }
    }

    // MARK: - Timer card

    private var timerCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(timerLabel)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppColors.textPrimary)
                Text("elapsed")
                    .font(DS.Typography.caption())
                    .foregroundStyle(AppColors.textMuted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(setsCompleted)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.brandPrimary)
                Text("sets done")
                    .font(DS.Typography.caption())
                    .foregroundStyle(AppColors.textMuted)
            }
        }
        .padding(DS.Spacing.lg)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
        .overlay(RoundedRectangle(cornerRadius: DS.Corner.card).strokeBorder(DS.Border.color, lineWidth: 1))
        .shadow(color: DS.Shadow.color, radius: DS.Shadow.radius, y: DS.Shadow.y)
    }

    private var timerLabel: String {
        String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
    }

    private var setsCompleted: Int {
        liveSets.flatMap { $0 }.filter(\.completed).count
    }

    // MARK: - Finish button

    private var finishButton: some View {
        Button { showFinish = true } label: {
            Text("FINISH WORKOUT")
                .font(.system(size: 15, weight: .heavy))
                .kerning(-0.5)
                .foregroundStyle(AppColors.textOnBrand)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
                .background(AppColors.brandPrimary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Init & save

    private func initSets() {
        liveSets = exercises.map { ex in
            let w = ProgressionEngine.startingWeight(for: ex, last: lastSession)
            let r = ProgressionEngine.startingReps(for: ex, last: lastSession)
            return (0..<ex.defaultSets).map { _ in LiveSet(weight: w, reps: r) }
        }
    }

    private func saveAndFinish() {
        let records: [ExerciseRecord] = zip(exercises, liveSets).compactMap { ex, sets in
            let done = sets.filter(\.completed).map { SetRecord(weight: $0.weight, reps: $0.reps, pace: $0.pace, distance: $0.distance, effort: $0.effort) }
            guard !done.isEmpty else { return nil }
            return ExerciseRecord(name: ex.name, type: ex.type, sets: done)
        }
        let session = WorkoutSession(date: Date(), durationSeconds: elapsed, exercises: records)
        WorkoutStore.append(session)
        Haptics.notification(.success)
        onComplete()
        // Show the summary card before dismissing
        completedSession = session
    }
}

// MARK: - Exercise card

private struct ExerciseCard: View {

    let exercise:     ExerciseTemplate
    let hint:         ProgressionHint?
    @Binding var sets: [LiveSet]
    let onAddSet:     () -> Void
    let onRemoveSet:  () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(exercise.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)

                if let h = hint {
                    HStack(spacing: DS.Spacing.sm) {
                        Text(h.prevSummary)
                            .font(DS.Typography.caption())
                            .foregroundStyle(AppColors.textMuted)
                        Spacer()
                        Text(h.advice)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppColors.textOnBrand)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(h.isUpgrade ? AppColors.brandPrimary : AppColors.warning)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.sm)

            Divider()
                .padding(.horizontal, DS.Spacing.md)

            // Set rows
            VStack(spacing: 0) {
                ForEach($sets) { $set in
                    let idx = sets.firstIndex(where: { $0.id == set.id }) ?? 0
                    SetRow(set: $set, exercise: exercise, index: idx)
                    if idx < sets.count - 1 {
                        Divider().padding(.leading, DS.Spacing.md)
                    }
                }
            }
            .padding(.bottom, DS.Spacing.xs)

            // Add / remove sets row
            Divider()
                .padding(.horizontal, DS.Spacing.md)

            HStack(spacing: DS.Spacing.sm) {
                // Remove set (disabled when only 1 set remains)
                Button(action: onRemoveSet) {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(sets.count > 1 ? AppColors.textSecondary : AppColors.textMuted)
                        .frame(width: 32, height: 32)
                        .background(AppColors.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(sets.count <= 1)

                Text("\(sets.count) set\(sets.count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.textMuted)

                // Add set
                Button(action: onAddSet) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.brandForeground)
                        .frame(width: 32, height: 32)
                        .background(AppColors.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
        .overlay(RoundedRectangle(cornerRadius: DS.Corner.card).strokeBorder(DS.Border.color, lineWidth: 1))
        .shadow(color: DS.Shadow.color, radius: DS.Shadow.radius, y: DS.Shadow.y)
    }
}

// MARK: - Set row

private struct SetRow: View {

    @Binding var set: LiveSet
    let exercise: ExerciseTemplate
    let index: Int

    @State private var secondsLeft = 0
    @State private var intervalRunning = false
    private let intervalTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isCardio: Bool { exercise.type == .cardio }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {

                // Set label
                Text("S\(index + 1)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(set.completed ? AppColors.brandPrimary : AppColors.textMuted)
                    .frame(width: 24)

                // Countdown timer (cardio) or weight stepper (weighted)
                if isCardio {
                    IntervalTimerView(
                        secondsLeft: $secondsLeft,
                        isRunning: $intervalRunning,
                        completed: set.completed
                    )
                } else {
                    WeightStepper(
                        value: $set.weight,
                        step: exercise.increment,
                        unit: "kg"
                    )
                }

                Text(isCardio ? "@" : "×")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textMuted)

                // Reps / incline
                RepsStepper(
                    value: $set.reps,
                    unit: isCardio ? "%" : "reps"
                )

                // Effort rating (cardio sets skip effort)
                if !isCardio {
                    EffortPicker(effort: $set.effort)
                }

                Spacer(minLength: 0)

                // Done circle
                Button {
                    withAnimation(.spring(duration: 0.2)) { set.completed.toggle() }
                    if set.completed {
                        Haptics.impact(.medium)
                        intervalRunning = false
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(set.completed ? AppColors.brandPrimary : Color.clear)
                            .frame(width: 34, height: 34)
                        if set.completed {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(AppColors.textOnBrand)
                        }
                    }
                    .overlay(
                        Circle().strokeBorder(
                            set.completed ? AppColors.brandPrimary : AppColors.border,
                            lineWidth: 1.5
                        )
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, 12)
            .background(set.completed ? AppColors.brandPrimary.opacity(0.06) : Color.clear)

            // Pace + distance row (cardio only)
            if isCardio {
                Divider().padding(.horizontal, DS.Spacing.md)
                HStack(spacing: DS.Spacing.xl) {
                    DistanceField(distance: $set.distance)
                    PaceField(pace: $set.pace)
                    Spacer()
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, 8)
                .background(set.completed ? AppColors.brandPrimary.opacity(0.03) : Color.clear)
            }
        }
        .onAppear {
            if isCardio && !set.completed && secondsLeft == 0 {
                secondsLeft = max(1, Int(set.weight * 60))
            }
        }
        .onReceive(intervalTimer) { _ in
            guard intervalRunning, !set.completed else { return }
            if secondsLeft > 1 {
                secondsLeft -= 1
                if secondsLeft == 30 { Haptics.impact(.heavy) }
            } else {
                secondsLeft = 0
                intervalRunning = false
                withAnimation(.spring(duration: 0.2)) { set.completed = true }
                Haptics.notification(.success)
            }
        }
    }
}

// MARK: - Weight stepper (tap value to type)

private struct WeightStepper: View {

    @Binding var value: Double
    let step: Double
    let unit: String

    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var focused: Bool

    private var formatted: String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }

    var body: some View {
        VStack(spacing: 1) {
            Group {
                if isEditing {
                    TextField("", text: $editText)
                        .keyboardType(.decimalPad)
                        .focused($focused)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.brandForeground)
                        .frame(minWidth: 38)
                        .onChange(of: focused) { _, isFocused in
                            if !isFocused { commitEdit() }
                        }
                } else {
                    Text(formatted)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(minWidth: 38)
                        .underline(color: AppColors.border)
                        .onTapGesture {
                            editText = formatted
                            isEditing = true
                            focused = true
                        }
                }
            }
            Text(unit)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(AppColors.textMuted)
        }
    }

    private func commitEdit() {
        let normalized = editText.replacingOccurrences(of: ",", with: ".")
        if let v = Double(normalized), v >= 0 {
            value = v
        }
        isEditing = false
    }

}

// MARK: - Reps stepper

private struct RepsStepper: View {

    @Binding var value: Int
    let unit: String

    var body: some View {
        HStack(spacing: 4) {
            stepBtn("minus") { value = max(1, value - 1) }
            VStack(spacing: 1) {
                Text("\(value)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(minWidth: 32)
                Text(unit)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(AppColors.textMuted)
            }
            stepBtn("plus") { value += 1 }
        }
    }

    @ViewBuilder
    private func stepBtn(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
                .frame(width: 26, height: 26)
                .background(AppColors.surface)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Effort picker

private struct EffortPicker: View {

    @Binding var effort: Effort?

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Effort.allCases, id: \.self) { e in
                Text(e.label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(effort == e ? Color.white : e.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(effort == e ? e.color : e.color.opacity(0.10))
                    .clipShape(Capsule())
                    .onTapGesture {
                        effort = effort == e ? nil : e
                        Haptics.impact(.light)
                    }
            }
        }
    }
}

// MARK: - Interval timer button

private struct IntervalTimerView: View {

    @Binding var secondsLeft: Int
    @Binding var isRunning: Bool
    let completed: Bool

    var body: some View {
        Button {
            guard !completed else { return }
            isRunning.toggle()
            if isRunning { Haptics.impact(.light) }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(isRunning ? AppColors.brandForeground : AppColors.textSecondary)
                VStack(spacing: 1) {
                    Text(timerLabel)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(isRunning ? AppColors.brandForeground : AppColors.textPrimary)
                    Text("min")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(AppColors.textMuted)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(completed)
    }

    private var timerLabel: String {
        String(format: "%d:%02d", secondsLeft / 60, secondsLeft % 60)
    }
}

// MARK: - Pace field (M:SS /km)

private struct PaceField: View {

    @Binding var pace: Double? // seconds/km

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 1) {
            TextField("–:––", text: $text)
                .keyboardType(.numbersAndPunctuation)
                .focused($focused)
                .multilineTextAlignment(.center)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(pace != nil ? AppColors.brandForeground : AppColors.textMuted)
                .frame(width: 44)
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { commit() }
                }
                .onAppear { text = pace.map(fmt) ?? "" }
            Text("/km")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(AppColors.textMuted)
        }
    }

    private func fmt(_ secs: Double) -> String {
        let s = Int(secs)
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }

    private func commit() {
        let raw = text.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { pace = nil; return }
        if raw.contains(":") {
            let parts = raw.split(separator: ":")
            if parts.count == 2, let m = Int(parts[0]), let s = Int(parts[1]), s < 60 {
                let total = Double(m * 60 + s)
                pace = total
                text = fmt(total)
                return
            }
        }
        if let secs = Double(raw) { pace = secs; text = fmt(secs) } else { pace = nil }
    }
}

// MARK: - Distance field (km)

private struct DistanceField: View {

    @Binding var distance: Double? // km

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 1) {
            TextField("0.00", text: $text)
                .keyboardType(.decimalPad)
                .focused($focused)
                .multilineTextAlignment(.center)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(distance != nil ? AppColors.brandForeground : AppColors.textMuted)
                .frame(width: 44)
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { commit() }
                }
                .onAppear {
                    if let d = distance { text = String(format: "%.2f", d) }
                }
            Text("km")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(AppColors.textMuted)
        }
    }

    private func commit() {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        if let v = Double(normalized), v > 0 {
            distance = v
            text = String(format: "%.2f", v)
        } else {
            distance = nil
        }
    }
}
