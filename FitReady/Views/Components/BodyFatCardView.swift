import SwiftUI

struct BodyFatCardView: View {

    let current: Double   // e.g. 22.5 (percent)
    let goal: Double      // e.g. 18.0 (percent)

    private var delta: Double { current - goal }
    private var isDecreasing: Bool { delta > 0 }  // going down toward goal
    private var accentColor: Color {
        isDecreasing ? Color(red: 1.0, green: 0.55, blue: 0.26) : Color(red: 0.20, green: 0.78, blue: 0.35)
    }
    /// Progress toward goal (0 = far away, 1 = at goal). Assumes ≤10% total journey.
    private var progress: Double {
        guard goal > 0 else { return 0 }
        let journey = 10.0
        return max(0, min(1, 1 - abs(delta) / journey))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Label("Body Fat", systemImage: "figure.stand")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color(.secondaryLabel))
                Spacer()
                Text(delta == 0 ? "Goal reached!" : String(format: "%+.1f%% to goal", -delta))
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(accentColor)
            }

            // Numbers
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(String(format: "%.1f", current))
                    .font(.system(size: 32, weight: .black, design: .rounded))
                Text(" %")
                    .font(.callout)
                    .foregroundStyle(Color(.secondaryLabel))
                Spacer()
                Image(systemName: isDecreasing ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(accentColor)
                Text(String(format: " %.1f%% goal", goal))
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
