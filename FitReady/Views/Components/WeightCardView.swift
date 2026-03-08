import SwiftUI

struct WeightCardView: View {

    let current: Double    // kg now
    let goal: Double       // kg target
    let start: Double?     // kg when they began (nil = not set)

    private var isLosing: Bool { current > goal }
    private var accentColor: Color {
        isLosing ? AppColors.amberBase : AppColors.greenBase
    }
    private var hasStart: Bool { (start ?? 0) > 0 }

    private var progress: Double {
        guard hasStart, let s = start, abs(s - goal) > 0.01 else {
            return max(0, min(1, 1 - abs(current - goal) / 15.0))
        }
        return max(0, min(1, abs(s - current) / abs(s - goal)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Top row: label + % badge ─────────────────
            HStack(alignment: .top, spacing: 8) {
                Label("Weight", systemImage: "scalemass.fill")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(AppColors.textSecondary)
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
                Text("kg")
                    .font(.title3)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.bottom, 4)

            // ── Delta from start ─────────────────────────
            if hasStart, let s = start, abs(s - current) > 0.05 {
                let symbol = s > current ? "↓" : "↑"
                Text("\(symbol) \(String(format: "%.1f kg from start", abs(s - current)))")
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundStyle(accentColor)
            }

            // ── Journey track ────────────────────────────
            VStack(spacing: 6) {
                JourneyTrack(progress: progress, color: accentColor)
                    .padding(.top, 16)
                HStack {
                    if hasStart, let s = start {
                        anchorLabel(value: String(format: "%.1f kg", s), tag: "start", alignment: .leading)
                    }
                    Spacer()
                    anchorLabel(value: String(format: "%.1f kg", goal), tag: "goal", alignment: .trailing)
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
                    Text(String(format: "%.1f kg to go", abs(current - goal)))
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
                .foregroundStyle(AppColors.textMuted)
        }
    }

    @ViewBuilder
    private func anchorLabel(value: String, tag: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(value)
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(AppColors.textSecondary)
            Text(tag)
                .font(.system(size: 10))
                .foregroundStyle(AppColors.textMuted)
        }
    }
}

// MARK: - Shared progress track (used by WeightCardView + BodyFatCardView)

struct JourneyTrack: View {

    let progress: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w          = geo.size.width
            let markerD: CGFloat = 18
            let trackH: CGFloat  = 5
            let vCenter          = (markerD - trackH) / 2
            let p                = max(0.0, min(1.0, progress))
            let fillW            = w * p
            let markerX          = max(0, min(w - markerD, fillW - markerD / 2))

            ZStack(alignment: .topLeading) {
                // Background track
                Capsule()
                    .fill(AppColors.border)
                    .frame(width: w, height: trackH)
                    .offset(y: vCenter)

                // Filled gradient
                if fillW > 0 {
                    Capsule()
                        .fill(LinearGradient(
                            colors: [color.opacity(0.25), color],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: fillW, height: trackH)
                        .offset(y: vCenter)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                }

                // Marker: white halo + colored core
                ZStack {
                    Circle()
                        .fill(AppColors.card)
                        .frame(width: markerD, height: markerD)
                        .shadow(color: color.opacity(0.35), radius: 5, x: 0, y: 2)
                    Circle()
                        .fill(color)
                        .frame(width: markerD - 6, height: markerD - 6)
                }
                .offset(x: markerX)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
            }
        }
        .frame(height: 18)
    }
}
