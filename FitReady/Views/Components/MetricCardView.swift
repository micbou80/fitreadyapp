import SwiftUI

struct MetricCardView: View {

    let title: String
    let value: String
    let unit: String
    /// Percentage change from baseline (positive = improved)
    let delta: Double?
    let icon: String
    /// Score contribution: -1, 0, or +1
    let score: Int

    private var scoreColor: Color {
        switch score {
        case  1: return Color(red: 0.20, green: 0.78, blue: 0.35)
        case -1: return Color(red: 0.88, green: 0.36, blue: 0.36)
        default: return Color(.tertiaryLabel)
        }
    }

    private var deltaText: String {
        guard let d = delta else { return "—" }
        let sign = d >= 0 ? "+" : ""
        return "\(sign)\(Int(d.rounded()))%"
    }

    private var arrowName: String {
        guard let d = delta else { return "minus" }
        if d > 1  { return "arrow.up" }
        if d < -1 { return "arrow.down" }
        return "minus"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title row
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(Color(.secondaryLabel))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(.secondaryLabel))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            // Value row
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(.label))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(unit)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(.secondaryLabel))
            }

            // Delta row
            HStack(spacing: 3) {
                Image(systemName: arrowName)
                    .font(.system(size: 9, weight: .bold))
                Text(deltaText)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(scoreColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}
