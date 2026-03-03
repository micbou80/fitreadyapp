import SwiftUI

/// Notification preference selector.
struct NotificationsView: View {

    @AppStorage("notificationLevel") private var notificationLevel: String = "moderate"

    private let levels: [(key: String, label: String, desc: String, icon: String, color: Color)] = [
        ("everything",   "Give me everything",
         "Workouts, meals, recovery insights, wins — all of it.",
         "bell.badge.fill",   .purple),
        ("moderate",     "Moderate",
         "Daily reminders and key recovery alerts only.",
         "bell.fill",         Color(hex: "1B7D38")),
        ("light",        "Super light",
         "Weekly summary and only the most important nudges.",
         "bell.slash",        Color(hex: "5B4FCF")),
        ("affirmations", "Affirmations only",
         "Just the motivational messages — nothing else.",
         "heart.fill",        Color(hex: "B45309")),
        ("off",          "Off",
         "No notifications. You're on your own.",
         "bell.slash.fill",   Color(.systemGray3)),
    ]

    var body: some View {
        ZStack {
            DS.Background.page.ignoresSafeArea()
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {

                    VStack(spacing: 0) {
                        Text("NOTIFICATION LEVEL")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(.secondaryLabel))
                            .kerning(0.5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.top, DS.Spacing.md)
                            .padding(.bottom, DS.Spacing.xs)

                        VStack(spacing: 0) {
                            ForEach(Array(levels.enumerated()), id: \.element.key) { idx, level in
                                if idx > 0 { Divider().padding(.leading, 56) }
                                levelRow(level)
                            }
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.bottom, DS.Spacing.md)
                    }
                    .background(DS.Background.card)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
                    .shadow(color: DS.Shadow.color, radius: DS.Shadow.radius, x: 0, y: DS.Shadow.y)

                    Spacer(minLength: DS.Spacing.xl)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func levelRow(_ level: (key: String, label: String, desc: String, icon: String, color: Color)) -> some View {
        Button {
            notificationLevel = level.key
            Haptics.impact(.light)
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: level.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(level.color)
                    .frame(width: 36, height: 36)
                    .background(level.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(level.label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(.label))
                    Text(level.desc)
                        .font(DS.Typography.caption())
                        .foregroundStyle(Color(.secondaryLabel))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if notificationLevel == level.key {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.purple)
                }
            }
            .padding(.vertical, DS.Spacing.md)
        }
        .buttonStyle(.plain)
    }
}
