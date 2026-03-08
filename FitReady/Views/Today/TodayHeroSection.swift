import SwiftUI

/// Hero card: the single daily decision.
/// Shows normal decision state during the day; switches to "Day Closed" state
/// after the user completes the evening check-out (until midnight).
struct TodayHeroSection: View {

    @ObservedObject var vm: TodayViewModel

    @AppStorage("lastCheckOutDate")  private var lastCheckOutDate:  String = ""
    @AppStorage("lastCheckOutMessage") private var lastCheckOutMessage: String = ""
    @AppStorage("checkOutsJSON")     private var checkOutsJSON:     String = "[]"
    @AppStorage("weeklyPlan")        private var weeklyPlan:        String = "W,L,W,L,W,R,R"

    private var isDayClosed: Bool {
        lastCheckOutDate == DailyCheckOut.todayKey()
    }

    var body: some View {
        if isDayClosed {
            closedHero
        } else {
            activeHero
        }
    }

    // MARK: - Active hero (normal day state)

    private var activeHero: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {

            // State chip
            Text(vm.readinessState.accessibilityLabel.uppercased())
                .font(DS.Typography.label())
                .foregroundStyle(DS.StateColor.primary(for: vm.readinessState))
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, 3)
                .background(DS.StateColor.primary(for: vm.readinessState).opacity(0.12))
                .clipShape(Capsule())

            // Headline
            Text(headlineText)
                .font(DS.Typography.hero())
                .foregroundStyle(AppColors.textPrimary)

            // Reassurance
            Text(reassuranceText)
                .font(DS.Typography.body())
                .foregroundStyle(AppColors.textSecondary)

            // Reason (muted)
            if !vm.readinessReason.isEmpty {
                Text(vm.readinessReason)
                    .font(DS.Typography.caption())
                    .foregroundStyle(AppColors.textMuted)
            }

            // Plan context
            if !vm.todayPlanLabel.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                    Text(vm.todayPlanLabel)
                        .font(DS.Typography.caption())
                }
                .foregroundStyle(AppColors.textMuted)
            }

            // See details
            Button {
                vm.detailsSheetVisible = true
                Haptics.impact(.light)
            } label: {
                HStack(spacing: 3) {
                    Text("See details")
                    Image(systemName: "chevron.right")
                }
                .font(DS.Typography.caption().weight(.semibold))
                .foregroundStyle(DS.StateColor.primary(for: vm.readinessState))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            Divider()
                .padding(.vertical, DS.Spacing.xs)

            // CTAs
            ctaStack
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(DS.Background.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Corner.card)
                .strokeBorder(DS.Border.color, lineWidth: 1)
        )
    }

    // MARK: - Closed hero (after evening check-out)

    private var closedHero: some View {
        let checkOut = DailyCheckOut.todayEntry(from: checkOutsJSON)

        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {

            // Badge
            Text("DAY CLOSED")
                .font(DS.Typography.label())
                .foregroundStyle(AppColors.greenText)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, 3)
                .background(AppColors.greenText.opacity(0.12))
                .clipShape(Capsule())

            // Affirmation
            Text(checkOut?.affirmationTitle ?? lastCheckOutMessage)
                .font(DS.Typography.hero())
                .foregroundStyle(AppColors.textPrimary)

            Text(checkOut?.affirmationBody ?? "Rest well tonight.")
                .font(DS.Typography.body())
                .foregroundStyle(AppColors.textSecondary)

            // Mini stats — single row
            if let co = checkOut, co.steps > 0 || co.proteinConsumed > 0 {
                Divider()
                    .padding(.vertical, DS.Spacing.xs)

                HStack(spacing: 0) {
                    miniStat(icon: "figure.walk", color: AppColors.greenText,
                             value: stepsFormatted(co.steps), hit: co.stepsHit)
                        .frame(maxWidth: .infinity, alignment: .center)
                    miniStat(icon: "🥚", color: AppColors.accent,
                             value: "\(co.proteinConsumed)g", hit: co.proteinHit)
                        .frame(maxWidth: .infinity, alignment: .center)
                    miniStat(icon: "bolt.fill", color: AppColors.amberBase,
                             value: "\(co.activeKcal) kcal", hit: co.activeHit)
                        .frame(maxWidth: .infinity, alignment: .center)
                    if co.kcalConsumed > 0, co.kcalTarget > 0 {
                        miniStat(icon: "minus.circle.fill",
                                 color: AppColors.amberText,
                                 value: deficitText(co),
                                 hit:   co.kcalConsumed <= co.kcalTarget)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }

            // Tomorrow signal
            Divider()
                .padding(.vertical, DS.Spacing.xs)

            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.dataSleep)
                Text("Tomorrow · \(tomorrowTypeLabel)")
                    .font(DS.Typography.caption())
                    .foregroundStyle(AppColors.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Corner.card)
                .fill(AppColors.greenBase.opacity(0.08))
        )
    }

    @ViewBuilder
    private func miniStat(icon: String, color: Color, value: String, hit: Bool) -> some View {
        HStack(spacing: 4) {
            let isEmoji = icon.unicodeScalars.first.map { $0.value > 127 } ?? false
            if isEmoji {
                Text(icon).font(.system(size: 13))
            } else {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color.opacity(hit ? 1 : 0.4))
            }
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(hit ? AppColors.textPrimary : AppColors.textMuted)
        }
    }

    private func stepsFormatted(_ n: Int) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        return fmt.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private func deficitText(_ co: DailyCheckOut) -> String {
        let balance = co.kcalTarget - co.kcalConsumed
        let abs = Swift.abs(balance)
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        let n = fmt.string(from: NSNumber(value: abs)) ?? "\(abs)"
        if abs <= 50 { return "On target" }
        return balance > 0 ? "−\(n) kcal" : "+\(n) kcal"
    }

    // MARK: - CTA stack

    private var ctaStack: some View {
        VStack(spacing: DS.Spacing.sm) {
            PrimaryCTAButton(
                label:  vm.recommendedAction.ctaLabel,
                state:  vm.readinessState,
                action: { vm.completeAction() }
            )
            Button {
                vm.showingScanner = true
                Haptics.impact(.light)
            } label: {
                Label("Log a meal", systemImage: "camera.viewfinder")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.brandPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.sm)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(AppColors.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Tomorrow (for closed hero)

    private var tomorrowLetter: String {
        let parts = weeklyPlan.components(separatedBy: ",")
        guard parts.count == 7 else { return "W" }
        let weekday = Calendar.current.component(.weekday, from: Date())
        let todayIndex = (weekday - 2 + 7) % 7
        return parts[(todayIndex + 1) % 7]
    }

    private var tomorrowTypeLabel: String {
        switch tomorrowLetter {
        case "W": return "Train day"
        case "L": return "Light session"
        default:  return "Rest day"
        }
    }

    // MARK: - Copy

    private var headlineText: String {
        switch vm.readinessState {
        case .green:  return "You're ready.\nGo make it count."
        case .yellow: return "Go lighter today.\nKeep the momentum."
        case .red:    return "Rest today.\nLet your body rebuild."
        }
    }

    private var reassuranceText: String {
        switch vm.readinessState {
        case .green:  return "Body primed, schedule clear. Push hard."
        case .yellow: return "Lighter days are how progress sticks."
        case .red:    return "Recovery is when you actually get stronger."
        }
    }
}
