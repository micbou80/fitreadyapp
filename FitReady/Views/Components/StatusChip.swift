import SwiftUI

/// Small pill showing an icon + value — used in the collapsed status row.
struct StatusChip: View {

    let icon:  String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(DS.Typography.caption())
                .foregroundStyle(Color(.label))
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, 5)
        .background(color.opacity(0.10))
        .clipShape(Capsule())
    }
}
