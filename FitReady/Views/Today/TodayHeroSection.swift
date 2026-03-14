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

    @State private var showMobility  = false
    @State private var showBreathing = false

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Hero card color helpers (light mode = always-dark card)

    private var heroTextColor: Color {
        colorScheme == .light ? Color(hex: "F2F2F2") : AppColors.textPrimary
    }
    private var heroSubtextColor: Color {
        colorScheme == .light ? Color(hex: "F2F2F2").opacity(0.75) : AppColors.textSecondary
    }
    private var heroMutedColor: Color {
        colorScheme == .light ? Color(hex: "F2F2F2").opacity(0.55) : AppColors.textMuted
    }
    private var heroBg: Color {
        colorScheme == .light ? Color(hex: "20422E") : .clear
    }
    private var heroStateColor: Color {
        colorScheme == .light
            ? AppColors.stateBase(for: vm.readinessState)
            : AppColors.stateTextStrong(for: vm.readinessState)
    }

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

            // Status override banner (sick / injured / on a break)
            if vm.currentUserStatus != .active {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: vm.currentUserStatus.icon)
                        .font(.system(size: 11, weight: .semibold))
                    Text(vm.currentUserStatus.tagline.uppercased())
                        .font(DS.Typography.label())
                        .kerning(0.3)
                }
                .foregroundStyle(vm.currentUserStatus.color)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, 3)
                .background(vm.currentUserStatus.color.opacity(0.12))
                .clipShape(Capsule())
            }

            // State chip
            Text(vm.readinessState.accessibilityLabel.uppercased())
                .font(DS.Typography.label())
                .foregroundStyle(heroStateColor)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, 3)
                .background(heroStateColor.opacity(0.12))
                .clipShape(Capsule())

            // Headline
            Text(headlineText)
                .font(DS.Typography.hero())
                .foregroundStyle(heroTextColor)

            // Reassurance
            Text(reassuranceText)
                .font(DS.Typography.body())
                .foregroundStyle(heroSubtextColor)

            // Reason (muted)
            if !vm.readinessReason.isEmpty {
                Text(vm.readinessReason)
                    .font(DS.Typography.caption())
                    .foregroundStyle(heroMutedColor)
            }

            // Plan context
            if !vm.todayPlanLabel.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                    Text(vm.todayPlanLabel)
                        .font(DS.Typography.caption())
                }
                .foregroundStyle(heroMutedColor)
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
                .foregroundStyle(heroStateColor)
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
        .background(heroBg)
        .background(AppColors.brandPrimary.opacity(0.08))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Corner.card)
                .strokeBorder(AppColors.stateBase(for: vm.readinessState).opacity(0.4), lineWidth: 1)
        )
        .shadow(color: DS.Shadow.color, radius: DS.Shadow.radius, y: DS.Shadow.y)
    }

    // MARK: - Closed hero (after evening check-out)

    private var closedHero: some View {
        let checkOut = DailyCheckOut.todayEntry(from: checkOutsJSON)

        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {

            // Badge
            Text("DAY CLOSED")
                .font(DS.Typography.label())
                .foregroundStyle(AppColors.brandPrimary)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, 3)
                .background(AppColors.brandPrimary.opacity(0.12))
                .clipShape(Capsule())

            // Affirmation
            Text(checkOut?.affirmationTitle ?? lastCheckOutMessage)
                .font(DS.Typography.hero())
                .foregroundStyle(heroTextColor)

            Text(checkOut?.affirmationBody ?? "Rest well tonight.")
                .font(DS.Typography.body())
                .foregroundStyle(heroSubtextColor)

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
                Image(systemName: tomorrowType.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(tomorrowType.color)
                Text("Tomorrow · \(tomorrowTypeLabel)")
                    .font(DS.Typography.caption())
                    .foregroundStyle(heroMutedColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(heroBg)
        .background(AppColors.brandPrimary.opacity(0.10))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Corner.card)
                .strokeBorder(AppColors.brandPrimary.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: DS.Shadow.color, radius: DS.Shadow.radius, y: DS.Shadow.y)
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
                .foregroundStyle(hit ? heroTextColor : heroMutedColor)
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
        HStack(spacing: DS.Spacing.sm) {
            Button { primaryCTAAction() } label: {
                Label(primaryCTALabel, systemImage: primaryCTAIcon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(heroStateColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.sm)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(AppColors.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showMobility)  { RecoveryWorkoutView() }
            .sheet(isPresented: $showBreathing) { BreathingExerciseView() }

            Button {
                secondaryCTAAction()
            } label: {
                Label(secondaryCTALabel, systemImage: secondaryCTAIcon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(heroStateColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.sm)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(AppColors.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Contextual CTA logic

    /// Hour of day used for time-aware copy (0–23).
    private var currentHour: Int { Calendar.current.component(.hour, from: Date()) }

    private var primaryCTALabel: String {
        // Status overrides
        switch vm.currentUserStatus {
        case .sick:    return "Rest today"
        case .injured: return "Start Mobility"
        case .onBreak: return "Breathe & relax"
        case .active:  break
        }
        // Time-of-day context for rest-day readiness
        if vm.readinessState == .red {
            return currentHour < 14 ? "Easy walk" : "Breathe & relax"
        }
        switch vm.todayPlanType {
        case .strength: return "Start Workout"
        case .run:      return "Go for a run"
        case .walk:     return "Take a walk"
        case .mobility: return "Start Mobility"
        case .rest:     return currentHour < 20 ? "Quick mobility" : "Breathe & relax"
        }
    }

    private var primaryCTAIcon: String {
        switch vm.currentUserStatus {
        case .sick:    return "moon.fill"
        case .injured: return "figure.flexibility"
        case .onBreak: return "wind"
        case .active:  break
        }
        if vm.readinessState == .red {
            return currentHour < 14 ? "figure.walk" : "wind"
        }
        return vm.todayPlanType.icon
    }

    private var secondaryCTALabel: String {
        // If it's evening, promote meal log
        if currentHour >= 18 { return "Log a meal" }
        // If nutrition is likely behind, nudge toward food
        if vm.collapsedStats.nutrition.kcalConsumed < vm.collapsedStats.nutrition.kcalTarget / 3
            && currentHour >= 12 {
            return "Log a meal"
        }
        // Default
        return "Log a meal"
    }

    private var secondaryCTAIcon: String {
        return "camera.viewfinder"
    }

    private func primaryCTAAction() {
        switch vm.currentUserStatus {
        case .sick:
            showBreathing = true
            Haptics.impact(.light)
        case .injured:
            showMobility = true
            Haptics.impact(.light)
        case .onBreak:
            showBreathing = true
            Haptics.impact(.light)
        case .active:
            if vm.readinessState == .red {
                if currentHour < 14 {
                    NotificationCenter.default.post(name: .switchToWorkoutTab, object: nil)
                } else {
                    showBreathing = true
                }
            } else {
                switch vm.todayPlanType {
                case .strength, .run, .walk:
                    NotificationCenter.default.post(name: .switchToWorkoutTab, object: nil)
                    Haptics.impact(.medium)
                case .mobility:
                    showMobility = true
                    Haptics.impact(.light)
                case .rest:
                    if currentHour < 20 {
                        showMobility = true
                    } else {
                        showBreathing = true
                    }
                    Haptics.impact(.light)
                }
            }
        }
    }

    private func secondaryCTAAction() {
        vm.showingScanner = true
        Haptics.impact(.light)
    }

    // MARK: - Tomorrow (for closed hero)

    private var tomorrowType: PlanDayType {
        let weekday    = Calendar.current.component(.weekday, from: Date())
        let todayIndex = (weekday - 2 + 7) % 7
        return PlanDayType.week(from: weeklyPlan)[(todayIndex + 1) % 7]
    }

    private var tomorrowTypeLabel: String { tomorrowType.label }

    // MARK: - Copy

    private var headlineText: String {
        // Status overrides take priority over biometric readiness copy
        switch vm.currentUserStatus {
        case .sick:    return "Take it easy today.\nYour body is fighting."
        case .injured: return "Protect your recovery.\nModified movement only."
        case .onBreak: return "Enjoy your break.\nYou've earned the rest."
        case .active:  break
        }
        switch (vm.readinessState, vm.todayPlanType) {
        case (.green, .strength): return "You're ready.\nGo make it count."
        case (.green, .run):      return "You're ready.\nTime to run."
        case (.green, .walk):     return "You're ready.\nGet those steps in."
        case (.green, .mobility): return "You're ready.\nMove and stretch."
        case (.green, .rest):     return "Rest day planned.\nYour body will thank you."
        case (.yellow, _):        return "Go lighter today.\nKeep the momentum."
        case (.red, _):           return "Rest today.\nLet your body rebuild."
        }
    }

    private var reassuranceText: String {
        switch vm.currentUserStatus {
        case .sick:    return "Skip training — rest is the best medicine."
        case .injured: return "Listen to your body. Gentle movement only."
        case .onBreak: return "Consistency matters. Breaks are part of the plan."
        case .active:  break
        }
        switch vm.readinessState {
        case .green:  return "Body primed, schedule clear. Push hard."
        case .yellow: return "Lighter days are how progress sticks."
        case .red:    return "Recovery is when you actually get stronger."
        }
    }
}
