import SwiftUI

struct WeightCardView: View {

    let current: Double
    let goal: Double

    private var delta: Double { current - goal }
    private var isLosing: Bool { delta > 0 }
    private var accentColor: Color {
        isLosing ? Color(red: 1.0, green: 0.55, blue: 0.26) : Color(red: 0.20, green: 0.78, blue: 0.35)
    }
    /// How far along toward the goal (0 = just started, 1 = at goal)
    private var progress: Double {
        guard goal > 0 else { return 0 }
        // Assume start = current (no progress yet if we only have one point)
        // Progress bar shows closeness: if within 0.5 kg = 100%, scales linearly
        let closeEnough = 15.0 // assume ≤15 kg total journey
        return max(0, min(1, 1 - abs(delta) / closeEnough))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Label("Weight", systemImage: "scalemass.fill")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color(.secondaryLabel))
                Spacer()
                Text(delta == 0 ? "Goal reached!" : String(format: "%+.1f kg to goal", -delta))
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(accentColor)
            }

            // Numbers
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(String(format: "%.1f", current))
                    .font(.system(size: 32, weight: .black, design: .rounded))
                Text(" kg")
                    .font(.callout)
                    .foregroundStyle(Color(.secondaryLabel))
                Spacer()
                Image(systemName: isLosing ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(accentColor)
                Text(String(format: " %.1f kg goal", goal))
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabel))
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(accentColor)
                        .frame(width: geo.size.width * progress, height: 8)
                        .animation(.spring(duration: 0.8), value: progress)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}
