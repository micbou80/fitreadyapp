import SwiftUI
import UIKit

// File-level timer — avoids publisher recreation on every re-render
private let breathTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

struct BreathingExerciseView: View {

    enum Phase { case preview, active, done }
    enum BreathPhase { case inhale, exhale }

    @Environment(\.dismiss) private var dismiss

    @State private var phase:          Phase       = .preview
    @State private var breathPhase:    BreathPhase = .inhale
    @State private var breathElapsed:  Int         = 0   // seconds in current breath phase
    @State private var totalRemaining: Int         = 300 // 5 min = 300 s
    @State private var orbScale:       CGFloat     = 0.45

    private let inhaleDuration = 3
    private let exhaleDuration = 4
    private let totalDuration  = 300

    // MARK: - Body

    var body: some View {
        ZStack {
            switch phase {
            case .preview: previewScreen
            case .active:  activeScreen
            case .done:    doneScreen
            }
        }
        .onReceive(breathTicker) { _ in
            guard phase == .active else { return }
            tick()
        }
        .onChange(of: phase) { _, newPhase in
            UIApplication.shared.isIdleTimerDisabled = (newPhase == .active)
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: - Preview screen

    private var previewScreen: some View {
        ZStack {
            DS.Background.page.ignoresSafeArea()

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
                        Image(systemName: "wind")
                            .font(.system(size: 44))
                            .foregroundStyle(AppColors.accent)
                            .frame(width: 76, height: 76)
                            .background(AppColors.accent.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 20))

                        Text("Breathe")
                            .font(.system(size: 26, weight: .bold, design: .rounded))

                        HStack(spacing: DS.Spacing.lg) {
                            Label("5 min",         systemImage: "clock")
                            Label("3s in · 4s out", systemImage: "lungs.fill")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)

                        Text("Slow your breathing to activate the\nparasympathetic system and lower cortisol.")
                            .font(DS.Typography.body())
                            .foregroundStyle(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.sm)

                    // Start button
                    Button(action: startBreathing) {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "play.fill")
                            Text("Start")
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

                    // Instructions
                    Text("HOW IT WORKS")
                        .font(DS.Typography.label())
                        .foregroundStyle(AppColors.textSecondary)
                        .kerning(0.5)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.top, DS.Spacing.xl)
                        .padding(.bottom, DS.Spacing.md)

                    VStack(spacing: 0) {
                        instructionRow(
                            number: "1",
                            title:  "Inhale through your nose",
                            detail: "3 seconds — feel your belly expand."
                        )
                        Divider().padding(.leading, 56)
                        instructionRow(
                            number: "2",
                            title:  "Exhale slowly through your mouth",
                            detail: "4 seconds — let your shoulders drop."
                        )
                        Divider().padding(.leading, 56)
                        instructionRow(
                            number: "3",
                            title:  "Follow the orb",
                            detail: "Expand with inhale, contract with exhale."
                        )
                    }
                    .padding(.horizontal, DS.Spacing.lg)

                    Spacer(minLength: DS.Spacing.xl)
                }
            }
        }
    }

    @ViewBuilder
    private func instructionRow(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Text(number)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.accent)
                .frame(width: 26, height: 26)
                .background(AppColors.accent.opacity(0.10))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DS.Typography.body())
                Text(detail)
                    .font(DS.Typography.caption())
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(.vertical, DS.Spacing.md)
    }

    // MARK: - Active screen

    private var activeScreen: some View {
        ZStack {
            // Full-screen gradient: dark base → raised surface, cohesive with dark-only palette
            LinearGradient(
                colors: [AppColors.bg, AppColors.raised],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {

                // Top bar: close + remaining time
                HStack {
                    Button { stopBreathing() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    Spacer()
                    Text(remainingText)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)

                Spacer()

                // Phase instruction
                VStack(spacing: DS.Spacing.xs) {
                    Text(phaseInstruction)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .animation(nil, value: breathPhase == .inhale)

                    Text("\(phaseCountdown)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.90))
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.linear(duration: 0.15), value: phaseCountdown)
                }
                .padding(.bottom, DS.Spacing.xl)

                // Animated orb
                ZStack {
                    // Outer halo — fixed boundary ring
                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 220, height: 220)
                    Circle()
                        .stroke(.white.opacity(0.14), lineWidth: 1.5)
                        .frame(width: 220, height: 220)

                    // Inner breathing orb
                    Circle()
                        .fill(.white.opacity(0.28))
                        .frame(width: 220, height: 220)
                        .scaleEffect(orbScale)
                        .shadow(color: .white.opacity(0.18), radius: 28, x: 0, y: 0)
                }

                Spacer()

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.15))
                            .frame(height: 3)
                        Capsule()
                            .fill(.white.opacity(0.65))
                            .frame(width: geo.size.width * progressFraction, height: 3)
                            .animation(.linear(duration: 1), value: totalRemaining)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xl)
            }
        }
    }

    // MARK: - Done screen

    private var doneScreen: some View {
        ZStack {
            DS.Background.page.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

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
                        Text("5 minutes complete.\nYour nervous system thanks you.")
                            .font(DS.Typography.body())
                            .foregroundStyle(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    HStack(spacing: DS.Spacing.md) {
                        statPill(icon: "clock",      value: "5 min")
                        statPill(icon: "lungs.fill",  value: "~42 cycles")
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)

                Spacer()

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

    @ViewBuilder
    private func statPill(icon: String, value: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(AppColors.accent)
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(AppColors.accent.opacity(0.10))
        .clipShape(Capsule())
    }

    // MARK: - Computed helpers

    private var phaseInstruction: String {
        breathPhase == .inhale ? "Inhale through nose" : "Exhale slowly"
    }

    private var phaseCountdown: Int {
        let dur = breathPhase == .inhale ? inhaleDuration : exhaleDuration
        return max(1, dur - breathElapsed)
    }

    private var progressFraction: Double {
        Double(totalDuration - totalRemaining) / Double(totalDuration)
    }

    private var remainingText: String {
        let m = totalRemaining / 60
        let s = totalRemaining % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Actions

    private func startBreathing() {
        breathPhase    = .inhale
        breathElapsed  = 0
        totalRemaining = totalDuration
        orbScale       = 0.45
        phase          = .active
        // Kick off the first inhale animation immediately
        withAnimation(.easeInOut(duration: Double(inhaleDuration))) {
            orbScale = 0.90
        }
        Haptics.impact(.medium)
    }

    private func stopBreathing() {
        orbScale = 0.45
        phase    = .preview
    }

    private func tick() {
        totalRemaining -= 1
        breathElapsed  += 1

        if totalRemaining <= 0 {
            withAnimation { phase = .done }
            Haptics.notification(.success)
            return
        }

        let phaseDur = breathPhase == .inhale ? inhaleDuration : exhaleDuration
        if breathElapsed >= phaseDur {
            breathElapsed = 0
            if breathPhase == .inhale {
                breathPhase = .exhale
                withAnimation(.easeInOut(duration: Double(exhaleDuration))) {
                    orbScale = 0.45
                }
            } else {
                breathPhase = .inhale
                withAnimation(.easeInOut(duration: Double(inhaleDuration))) {
                    orbScale = 0.90
                }
            }
            Haptics.impact(.light)
        }
    }
}
