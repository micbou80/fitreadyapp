import SwiftUI

/// Guided interval run sheet.
/// Cycles: Ready → Run(n) → Rest(n) → Run(n+1) … → Done
/// Haptics: heavy at 30 s remaining in a run interval; success on interval complete / session done.
struct IntervalRunSheet: View {

    let program: WorkoutProgram

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var healthKit: HealthKitManager

    // MARK: - Phase

    enum Phase: Equatable {
        case ready
        case running(interval: Int)   // 1-indexed
        case resting(nextInterval: Int)
        case done
    }

    @State private var phase            = Phase.ready
    @State private var secondsLeft      = 0
    @State private var isPaused         = false
    @State private var elapsed          = 0
    @State private var completedSession: WorkoutSession? = nil

    /// Wall-clock anchor for elapsed time — recomputed on foreground return.
    @State private var startDate:     Date = Date()
    /// Wall-clock anchor for the current phase countdown — recomputed on foreground return.
    @State private var phaseStartDate: Date = Date()
    /// Total elapsed seconds before the current active phase began (accumulated across pauses).
    @State private var elapsedBeforePhase: Int = 0
    /// Seconds remaining at the moment a pause began (for resuming correctly).
    @State private var pausedSecondsLeft: Int = 0

    // Per-interval logged data (0-indexed)
    @State private var distances: [Double?] = []
    @State private var paces:     [Double?] = []

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: - Template values

    private var ex: ExerciseTemplate? { program.exercises.first }
    private var totalIntervals: Int { ex?.defaultSets ?? 5 }
    private var runSecs: Int        { Int((ex?.defaultWeight ?? 3) * 60) }
    private var restSecs: Int       { (ex?.defaultReps ?? 1) * 60 }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Background.page.ignoresSafeArea()
                VStack(spacing: 0) {
                    Spacer(minLength: 56)
                    phaseCluster
                    Spacer()
                    if let idx = logIndex {
                        logCard(idx: idx)
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.bottom, DS.Spacing.md)
                            .animation(.spring(duration: 0.35), value: logIndex)
                    }
                    ctaRow
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.bottom, DS.Spacing.xl)
                }
            }
            .navigationTitle(program.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .onAppear {
            distances   = Array(repeating: nil, count: totalIntervals)
            // Pre-populate pace from HealthKit if available (most recent running speed)
            let hkPace  = healthKit.recentRunningPaceSecsPerKm
            paces       = Array(repeating: hkPace, count: totalIntervals)
            secondsLeft = runSecs
        }
        .onReceive(clock) { _ in tick() }
        // Re-anchor when returning from background so elapsed time stays accurate
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
        ) { _ in
            reanchorOnForeground()
        }
        .sheet(item: $completedSession) { session in
            WorkoutSummarySheet(session: session, program: program)
        }
    }

    // MARK: - Phase cluster

    private var phaseCluster: some View {
        VStack(spacing: DS.Spacing.md) {
            Text(headerLabel)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
                .kerning(0.8)
                .animation(.none, value: phase)

            Text(phaseLabel)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(phaseColor)
                .kerning(1.5)
                .animation(.easeInOut(duration: 0.2), value: phase)

            Text(timerText)
                .font(.system(size: 72, weight: .bold, design: .monospaced))
                .foregroundStyle(phaseColor)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.2), value: secondsLeft)

            Text(subtitleLabel)
                .font(DS.Typography.caption())
                .foregroundStyle(AppColors.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xl)
                .animation(.none, value: phase)
        }
    }

    // MARK: - Log card (shown during rest and done to capture the interval just finished)

    private var logIndex: Int? {
        switch phase {
        case .resting(let next):
            let idx = next - 2
            return (idx >= 0 && idx < totalIntervals) ? idx : nil
        case .done:
            return totalIntervals - 1
        default:
            return nil
        }
    }

    @ViewBuilder
    private func logCard(idx: Int) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            Text("LOG INTERVAL \(idx + 1)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
                .kerning(0.5)
            HStack(spacing: DS.Spacing.xl) {
                SplitDistanceField(value: Binding(
                    get: { distances[idx] },
                    set: { distances[idx] = $0 }
                ))
                SplitPaceField(value: Binding(
                    get: { paces[idx] },
                    set: { paces[idx] = $0 }
                ))
            }
        }
        .padding(DS.Spacing.lg)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
        .overlay(RoundedRectangle(cornerRadius: DS.Corner.card).strokeBorder(DS.Border.color, lineWidth: 1))
        .shadow(color: DS.Shadow.color, radius: DS.Shadow.radius, y: DS.Shadow.y)
    }

    // MARK: - CTA row

    @ViewBuilder
    private var ctaRow: some View {
        if phase == .ready {
            primaryBtn("START") { start() }
        } else if case .running = phase {
            HStack(spacing: DS.Spacing.sm) {
                ghostBtn(isPaused ? "RESUME" : "PAUSE") {
                    if isPaused {
                        // Resuming: re-anchor the phase start so countdown is correct
                        phaseStartDate     = Date().addingTimeInterval(-Double(runSecs - pausedSecondsLeft))
                        startDate          = Date().addingTimeInterval(-Double(elapsed - elapsedBeforePhase))
                    } else {
                        // Pausing: snapshot current secondsLeft
                        pausedSecondsLeft  = secondsLeft
                    }
                    isPaused.toggle()
                    Haptics.impact(.light)
                }
                ghostBtn("NEXT →") { skipRun() }
            }
        } else if case .resting = phase {
            ghostBtn("SKIP REST") { skipRest() }
        } else {
            primaryBtn("SAVE WORKOUT") { saveAndFinish() }
        }
    }

    @ViewBuilder
    private func primaryBtn(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                Spacer()
                Text(label)
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
    }

    @ViewBuilder
    private func ghostBtn(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.brandForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(AppColors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Label helpers

    private var headerLabel: String {
        switch phase {
        case .ready:
            return "\(totalIntervals) INTERVALS · \(Int(ex?.defaultWeight ?? 3)) MIN EACH"
        case .running(let i):
            return "INTERVAL \(i) OF \(totalIntervals)"
        case .resting(let next):
            return "INTERVAL \(next - 1) COMPLETE"
        case .done:
            return "ALL DONE"
        }
    }

    private var phaseLabel: String {
        switch phase {
        case .ready:              return "READY"
        case .running:            return isPaused ? "PAUSED" : "RUN"
        case .resting:            return "REST"
        case .done:               return "COMPLETE"
        }
    }

    private var phaseColor: Color {
        switch phase {
        case .ready:              return AppColors.textSecondary
        case .running:            return isPaused ? AppColors.warning : AppColors.brandPrimary
        case .resting:            return AppColors.textSecondary
        case .done:               return AppColors.sage
        }
    }

    private var timerText: String {
        switch phase {
        case .ready:
            return String(format: "%d:%02d", runSecs / 60, runSecs % 60)
        case .running, .resting:
            return String(format: "%d:%02d", secondsLeft / 60, secondsLeft % 60)
        case .done:
            return String(format: "%d:%02d", elapsed / 60, elapsed % 60)
        }
    }

    private var subtitleLabel: String {
        switch phase {
        case .ready:
            return "+ \(restSecs / 60) min rest between intervals"
        case .running(let i):
            return i < totalIntervals
                ? "→ \(restSecs / 60) min rest after"
                : "Last interval — finish strong"
        case .resting(let next):
            return "Up next: \(Int(ex?.defaultWeight ?? 3)) min run · interval \(next) of \(totalIntervals)"
        case .done:
            return "Total time"
        }
    }

    // MARK: - Timer logic

    private func tick() {
        guard !isPaused, phase != .ready, phase != .done else { return }

        // Re-derive elapsed from wall-clock anchor to stay accurate after background
        elapsed = elapsedBeforePhase + Int(Date().timeIntervalSince(startDate))

        // Countdown is wall-clock based too
        let phaseElapsed = Int(Date().timeIntervalSince(phaseStartDate))
        let phaseDuration: Int
        if case .running = phase { phaseDuration = runSecs }
        else                     { phaseDuration = restSecs }
        let remaining = max(0, phaseDuration - phaseElapsed)

        // Haptic warning at 30 s remaining on a run interval
        if case .running = phase, secondsLeft > 30, remaining <= 30 {
            Haptics.impact(.heavy)
        }
        secondsLeft = remaining

        if remaining == 0 {
            if case .running = phase { advanceFromRun() }
            else if case .resting = phase { advanceFromRest() }
        }
    }

    private func start() {
        startDate           = Date()
        phaseStartDate      = Date()
        elapsedBeforePhase  = 0
        elapsed             = 0
        secondsLeft         = runSecs
        withAnimation { phase = .running(interval: 1) }
        Haptics.impact(.medium)
    }

    private func advanceFromRun() {
        guard case .running(let i) = phase else { return }
        Haptics.notification(.success)
        // Accumulate elapsed so it keeps counting through rests
        elapsedBeforePhase = elapsed
        if i >= totalIntervals {
            withAnimation { phase = .done }
        } else {
            withAnimation { phase = .resting(nextInterval: i + 1) }
            phaseStartDate = Date()
            secondsLeft    = restSecs
        }
    }

    private func advanceFromRest() {
        guard case .resting(let next) = phase else { return }
        elapsedBeforePhase = elapsed
        phaseStartDate     = Date()
        secondsLeft        = runSecs
        withAnimation { phase = .running(interval: next) }
        Haptics.impact(.heavy)
    }

    private func skipRun() { advanceFromRun() }
    private func skipRest() { advanceFromRest() }

    /// Called when the app returns from background. Re-derives all time values from wall-clock.
    private func reanchorOnForeground() {
        guard !isPaused, phase != .ready, phase != .done else { return }
        let now           = Date()
        elapsed           = elapsedBeforePhase + Int(now.timeIntervalSince(startDate))
        let phaseElapsed  = Int(now.timeIntervalSince(phaseStartDate))
        let phaseDuration: Int
        switch phase {
        case .running:  phaseDuration = runSecs
        case .resting:  phaseDuration = restSecs
        default:        return
        }
        let remaining = max(0, phaseDuration - phaseElapsed)
        secondsLeft   = remaining
        if remaining == 0 {
            switch phase {
            case .running:  advanceFromRun()
            case .resting:  advanceFromRest()
            default:        break
            }
        }
    }

    // MARK: - Save

    private func saveAndFinish() {
        guard let exercise = ex else { dismiss(); return }
        let sets = (0..<totalIntervals).map { i in
            SetRecord(weight: exercise.defaultWeight, reps: exercise.defaultReps,
                      pace: paces[i], distance: distances[i])
        }
        let record  = ExerciseRecord(name: exercise.name, type: exercise.type, sets: sets)
        let session = WorkoutSession(date: Date(), durationSeconds: elapsed, exercises: [record])
        WorkoutStore.append(session)
        Haptics.notification(.success)
        // Show the summary card
        completedSession = session
    }
}

// MARK: - Split distance field

private struct SplitDistanceField: View {

    @Binding var value: Double?

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 4) {
            TextField("0.00", text: $text)
                .keyboardType(.decimalPad)
                .focused($focused)
                .multilineTextAlignment(.center)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(value != nil ? AppColors.brandForeground : AppColors.textMuted)
                .frame(width: 72)
                .onChange(of: focused) { _, f in if !f { commit() } }
                .onAppear { if let v = value { text = String(format: "%.2f", v) } }
            Text("km")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.textMuted)
        }
    }

    private func commit() {
        let n = text.replacingOccurrences(of: ",", with: ".")
        if let v = Double(n), v > 0 {
            value = v
            text  = String(format: "%.2f", v)
        } else {
            value = nil
        }
    }
}

// MARK: - Split pace field

private struct SplitPaceField: View {

    @Binding var value: Double? // seconds/km

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 4) {
            TextField("–:––", text: $text)
                .keyboardType(.numbersAndPunctuation)
                .focused($focused)
                .multilineTextAlignment(.center)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(value != nil ? AppColors.brandForeground : AppColors.textMuted)
                .frame(width: 72)
                .onChange(of: focused) { _, f in if !f { commit() } }
                .onAppear { if let v = value { text = fmt(v) } }
            Text("/km")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.textMuted)
        }
    }

    private func fmt(_ secs: Double) -> String {
        let s = Int(secs)
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }

    private func commit() {
        let raw = text.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { value = nil; return }
        if raw.contains(":") {
            let parts = raw.split(separator: ":")
            if parts.count == 2, let m = Int(parts[0]), let s = Int(parts[1]), s < 60 {
                let total = Double(m * 60 + s)
                value = total
                text  = fmt(total)
                return
            }
        }
        if let secs = Double(raw) { value = secs; text = fmt(secs) } else { value = nil }
    }
}
