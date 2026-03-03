import SwiftUI

struct ReadinessRingView: View {

    let score: ReadinessScore

    @State private var progress: Double = 0

    private let ringSize: CGFloat  = 240
    private let ringWidth: CGFloat = 18

    // Colors for the three zones (muted so the active arc pops)
    private let restColor  = AppColors.redBase
    private let lightColor = AppColors.amberBase
    private let readyColor = AppColors.greenBase

    // totalScore (-3…+3) linearly mapped to 0-100
    private var displayScore: Int {
        Int(round(Double(score.totalScore + 3) / 6.0 * 100))
    }

    // Ring fill fraction derived from actual score, not fixed per verdict
    private var targetProgress: Double {
        Double(score.totalScore + 3) / 6.0
    }

    var body: some View {
        ZStack {

            // ── Zone background arcs ─────────────────────
            // Rest zone: 0 → 1/3
            Circle()
                .trim(from: 0, to: 1 / 3.0)
                .stroke(restColor.opacity(0.18), style: StrokeStyle(lineWidth: ringWidth, lineCap: .butt))
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(-90))

            // Light zone: 1/3 → 2/3
            Circle()
                .trim(from: 1 / 3.0, to: 2 / 3.0)
                .stroke(lightColor.opacity(0.18), style: StrokeStyle(lineWidth: ringWidth, lineCap: .butt))
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(-90))

            // Ready zone: 2/3 → 1
            Circle()
                .trim(from: 2 / 3.0, to: 1)
                .stroke(readyColor.opacity(0.18), style: StrokeStyle(lineWidth: ringWidth, lineCap: .butt))
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(-90))

            // ── Zone boundary tick marks ─────────────────
            tick(at: 1 / 3.0)
            tick(at: 2 / 3.0)

            // ── Active arc ───────────────────────────────
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [score.verdict.color.opacity(0.55), score.verdict.color],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(-90))

            // ── Inner glow ───────────────────────────────
            Circle()
                .fill(score.verdict.color.opacity(0.08))
                .frame(width: ringSize - ringWidth * 2 - 16)

            // ── Center content ───────────────────────────
            VStack(spacing: 2) {
                // Score number
                Text("\(displayScore)")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(score.verdict.color)
                    .contentTransition(.numericText())

                // Label
                Text("READINESS")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
                    .kerning(1.2)

                Spacer().frame(height: 10)

                // Metric indicator dots
                HStack(spacing: 16) {
                    metricDot(icon: "waveform.path.ecg", metricScore: score.hrvScore)
                    metricDot(icon: "heart.fill",        metricScore: score.rhrScore)
                    metricDot(icon: "moon.fill",         metricScore: score.sleepScore)
                }
            }
        }
        .onAppear { animateIn() }
        .onChange(of: score.verdict) {
            progress = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { animateIn() }
        }
    }

    // MARK: - Helpers

    private func animateIn() {
        withAnimation(.spring(duration: 1.2, bounce: 0.15).delay(0.2)) {
            progress = targetProgress
        }
    }

    /// A thin capsule that cuts across the track at a given ring position (0–1).
    private func tick(at fraction: Double) -> some View {
        let angle = fraction * 360.0 - 90.0
        return Capsule()
            .fill(AppColors.background)
            .frame(width: ringWidth + 2, height: 3)
            .offset(y: -(ringSize / 2))
            .rotationEffect(.degrees(angle))
    }

    /// Small colored icon representing one metric's score.
    @ViewBuilder
    private func metricDot(icon: String, metricScore: Int) -> some View {
        let color: Color = {
            switch metricScore {
            case  1: return readyColor
            case -1: return restColor
            default: return lightColor
            }
        }()
        Image(systemName: icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
    }
}
