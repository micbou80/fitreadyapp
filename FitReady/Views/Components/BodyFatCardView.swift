import SwiftUI

struct BodyFatCardView: View {

    let current: Double    // % now
    let goal: Double       // % target
    let start: Double?     // % when they began (nil = not set)

    private var isDecreasing: Bool { current > goal }
    private var accentColor: Color {
        isDecreasing ? AppColors.amberBase : AppColors.greenBase
    }
    private var hasStart: Bool { (start ?? 0) > 0 }

    private var progress: Double {
        guard hasStart, let s = start, abs(s - goal) > 0.01 else {
            return max(0, min(1, 1 - abs(current - goal) / 10.0))
        }
        return max(0, min(1, abs(s - current) / abs(s - goal)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Top row: label + % badge ─────────────────
            HStack(alignment: .top, spacing: 8) {
                Label("Body Fat", systemImage: "figure.stand")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color(.secondaryLabel))
                Spacer()
                if hasStart {
                    pctBadge(pct: Int((progress * 100).rounded()))
                }
            }
            .padding(.bottom, 12)

            // ── Current value ────────────────────────────
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", current))
                    .font(.system(size: 38, weight: .black, design: .rounded))
                Text("%")
                    .font(.title3)
                    .foregroundStyle(Color(.secondaryLabel))
            }
            .padding(.bottom, 4)

            // ── Delta from start ─────────────────────────
            if hasStart, let s = start, abs(s - current) > 0.05 {
                let symbol = s > current ? "↓" : "↑"
                Text("\(symbol) \(String(format: "%.1f%% from start", abs(s - current)))")
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundStyle(accentColor)
            }

            // ── Journey track ────────────────────────────
            VStack(spacing: 6) {
                JourneyTrack(progress: progress, color: accentColor)
                    .padding(.top, 16)
                HStack {
                    if hasStart, let s = start {
                        anchorLabel(value: String(format: "%.1f%%", s), tag: "start", alignment: .leading)
                    }
                    Spacer()
                    anchorLabel(value: String(format: "%.1f%%", goal), tag: "goal", alignment: .trailing)
                }
            }
            .padding(.bottom, 14)

            // ── Divider + to-go stat ─────────────────────
            Divider().padding(.bottom, 10)

            HStack(spacing: 5) {
                if current == goal {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.greenBase)
                    Text("Goal reached!")
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.greenBase)
                } else {
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accentColor)
                    Text(String(format: "%.1f%% to go", abs(current - goal)))
                        .fontWeight(.semibold)
                }
                Spacer()
            }
            .font(.subheadline)
        }
        .padding(16)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppColors.shadowColor, radius: 10, x: 0, y: 3)
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func pctBadge(pct: Int) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(String(pct))
                    .font(.system(size: 30, weight: .black, design: .rounded))
                Text("%")
                    .font(.system(size: 18, weight: .black, design: .rounded))
            }
            .foregroundStyle(accentColor)
            Text("complete")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(.tertiaryLabel))
        }
    }

    @ViewBuilder
    private func anchorLabel(value: String, tag: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(value)
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(Color(.secondaryLabel))
            Text(tag)
                .font(.system(size: 10))
                .foregroundStyle(Color(.tertiaryLabel))
        }
    }
}
