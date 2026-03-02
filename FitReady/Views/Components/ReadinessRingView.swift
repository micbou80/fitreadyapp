import SwiftUI

struct ReadinessRingView: View {

    let score: ReadinessScore

    @State private var progress: Double = 0

    private let ringSize: CGFloat  = 240
    private let ringWidth: CGFloat = 18

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color(.systemGray5), lineWidth: ringWidth)
                .frame(width: ringSize, height: ringSize)

            // Progress arc
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

            // Soft inner glow
            Circle()
                .fill(score.verdict.color.opacity(0.09))
                .frame(width: ringSize - ringWidth * 2 - 16)

            // Center icon
            Image(systemName: score.verdict.icon)
                .font(.system(size: 52, weight: .medium))
                .foregroundStyle(score.verdict.color)
        }
        .onAppear { animateIn() }
        .onChange(of: score.verdict) {
            progress = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { animateIn() }
        }
    }

    private func animateIn() {
        withAnimation(.spring(duration: 1.2, bounce: 0.15).delay(0.2)) {
            progress = score.verdict.ringProgress
        }
    }
}
