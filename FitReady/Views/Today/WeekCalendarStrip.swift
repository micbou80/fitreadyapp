import SwiftUI

/// Horizontal 7-day week strip (Mon → Sun).
/// Today shows a coloured readiness badge with the workout-type letter (W / L / R).
/// Past days are faded; future days are at half opacity.
struct WeekCalendarStrip: View {

    @ObservedObject var vm: TodayViewModel

    // MARK: - Day model

    private struct WeekDay: Identifiable {
        let id:        Int     // 0-6 (Mon=0 … Sun=6)
        let initial:   String
        let dayNumber: Int
        let isToday:   Bool
        let isPast:    Bool
    }

    // MARK: - Week data

    private var weekDays: [WeekDay] {
        let cal     = Calendar.current
        let today   = Date()
        // Weekday component: 1=Sun, 2=Mon … 7=Sat
        // offsetToMonday: how many days back to reach Monday of this week
        let weekday        = cal.component(.weekday, from: today)
        let offsetToMonday = (weekday - 2 + 7) % 7
        let initials       = ["M", "T", "W", "T", "F", "S", "S"]

        return (0..<7).compactMap { i in
            let dayOffset = i - offsetToMonday
            guard let date = cal.date(byAdding: .day, value: dayOffset, to: today) else { return nil }
            return WeekDay(
                id:        i,
                initial:   initials[i],
                dayNumber: cal.component(.day, from: date),
                isToday:   cal.isDateInToday(date),
                isPast:    date < cal.startOfDay(for: today)
            )
        }
    }

    private var todayBadgeLetter: String {
        switch vm.readinessState {
        case .green:  return "W"   // Workout
        case .yellow: return "L"   // Light
        case .red:    return "R"   // Rest
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {

            Text(Date().formatted(.dateTime.month(.wide).year()))
                .font(DS.Typography.caption())
                .foregroundStyle(Color(.secondaryLabel))
                .padding(.horizontal, 2)

            HStack(spacing: 0) {
                ForEach(weekDays) { day in
                    Spacer(minLength: 0)
                    dayCellView(day)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Background.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
        .shadow(color: DS.Shadow.color, radius: DS.Shadow.radius, x: 0, y: DS.Shadow.y)
    }

    // MARK: - Day cell

    @ViewBuilder
    private func dayCellView(_ day: WeekDay) -> some View {
        VStack(spacing: 5) {
            Text(day.initial)
                .font(DS.Typography.caption())
                .foregroundStyle(
                    day.isToday
                        ? DS.StateColor.primary(for: vm.readinessState)
                        : Color(.tertiaryLabel)
                )

            if day.isToday {
                ZStack {
                    Capsule()
                        .fill(DS.StateColor.primary(for: vm.readinessState))
                        .frame(width: 34, height: 34)
                    Text(todayBadgeLetter)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            } else {
                Text("\(day.dayNumber)")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(
                        day.isPast
                            ? Color(.label).opacity(0.2)
                            : Color(.label).opacity(0.5)
                    )
                    .frame(width: 34, height: 34)
            }
        }
    }
}
