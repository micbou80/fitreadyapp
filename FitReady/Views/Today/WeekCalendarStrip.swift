import SwiftUI

/// Calendar header: "Today" title + profile avatar, then the full Mon→Sun week strip.
///
/// Each day shows its planned workout type (W / L / R) from `weeklyPlan` AppStorage.
/// Today's badge is driven by the actual live readiness state; past days are faded.
/// Tapping the profile avatar pushes ProfileView onto the navigation stack.
struct WeekCalendarStrip: View {

    @ObservedObject var vm: TodayViewModel

    @AppStorage("profilePhotoData") private var profilePhotoData: Data = Data()
    /// Comma-separated plan letters for Mon–Sun, e.g. "W,L,W,L,W,R,R"
    @AppStorage("weeklyPlan")       private var weeklyPlan: String = "W,L,W,L,W,R,R"

    // MARK: - Day model

    private struct WeekDay: Identifiable {
        let id:         Int     // 0=Mon … 6=Sun
        let initial:    String
        let dayNumber:  Int
        let isToday:    Bool
        let isPast:     Bool
        let planLetter: String  // "W", "L", or "R"
    }

    // MARK: - Derived data

    private var planLetters: [String] {
        let parts = weeklyPlan.components(separatedBy: ",")
        return parts.count == 7 ? parts : Array(repeating: "W", count: 7)
    }

    private var weekDays: [WeekDay] {
        let cal            = Calendar.current
        let today          = Date()
        let weekday        = cal.component(.weekday, from: today) // 1=Sun … 7=Sat
        let offsetToMonday = (weekday - 2 + 7) % 7
        let initials       = ["M", "T", "W", "T", "F", "S", "S"]
        let letters        = planLetters

        return (0..<7).compactMap { i in
            let dayOffset = i - offsetToMonday
            guard let date = cal.date(byAdding: .day, value: dayOffset, to: today) else { return nil }
            return WeekDay(
                id:         i,
                initial:    initials[i],
                dayNumber:  cal.component(.day, from: date),
                isToday:    cal.isDateInToday(date),
                isPast:     date < cal.startOfDay(for: today),
                planLetter: i < letters.count ? letters[i] : "W"
            )
        }
    }

    /// Today's letter comes from current readiness; other days come from the weekly plan.
    private var todayBadgeLetter: String {
        switch vm.readinessState {
        case .green:  return "W"
        case .yellow: return "L"
        case .red:    return "R"
        }
    }

    private func planColor(for letter: String, isToday: Bool, isPast: Bool) -> Color {
        let base: Color
        switch letter {
        case "W": base = isToday ? DS.StateColor.primary(for: vm.readinessState) : Color(hex: "1B7D38")
        case "L": base = isToday ? DS.StateColor.primary(for: vm.readinessState) : Color(hex: "B45309")
        default:  base = Color(.systemGray3)
        }
        return isPast && !isToday ? base.opacity(0.35) : base
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {

            // — Header: "Today" title + profile avatar —
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text(Date().formatted(.dateTime.month(.wide).year()))
                        .font(DS.Typography.caption())
                        .foregroundStyle(Color(.secondaryLabel))
                }
                Spacer()
                NavigationLink(destination: ProfileView()) {
                    profileAvatar
                }
                .buttonStyle(.plain)
            }

            // — Day strip —
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

    // MARK: - Profile avatar

    @ViewBuilder
    private var profileAvatar: some View {
        if !profilePhotoData.isEmpty, let img = UIImage(data: profilePhotoData) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: 42, height: 42)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .foregroundStyle(Color(.systemGray3))
                .frame(width: 42, height: 42)
        }
    }

    // MARK: - Day cell

    @ViewBuilder
    private func dayCellView(_ day: WeekDay) -> some View {
        let letter = day.isToday ? todayBadgeLetter : day.planLetter
        let color  = planColor(for: letter, isToday: day.isToday, isPast: day.isPast)

        VStack(spacing: 4) {
            // Day initial
            Text(day.initial)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(.tertiaryLabel))

            if day.isToday {
                // Large filled capsule: plan letter on top, date number below
                ZStack {
                    Capsule()
                        .fill(color)
                        .frame(width: 34, height: 52)
                    VStack(spacing: 0) {
                        Text(letter)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("\(day.dayNumber)")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
            } else {
                // Date number + tiny plan badge underneath
                VStack(spacing: 3) {
                    Text("\(day.dayNumber)")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(
                            day.isPast ? Color(.label).opacity(0.25) : Color(.label).opacity(0.7)
                        )
                        .frame(width: 34, height: 28)
                    Text(letter)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 13)
                        .background(color)
                        .clipShape(Capsule())
                }
            }
        }
    }
}
