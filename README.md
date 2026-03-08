# FitReady

**Know in 10 seconds whether to train hard, go light, or rest.**

FitReady reads your Apple Health data and gives you one clear daily verdict — no dashboards, no noise, no guilt.

---

## What it does

Each morning, FitReady looks at your HRV, resting heart rate, and sleep from the past 7 days and compares today against your personal baseline. The result is a single, honest answer:

| Verdict | Meaning |
|---------|---------|
| 🟢 **Ready to Train** | Your body is recovered. Go for it. |
| 🟡 **Go Light** | Not fully recovered. Train, but dial it back. |
| 🔴 **Rest Day** | Your body is asking for recovery. Listen to it. |

---

## Features

- **Daily readiness score** — HRV, resting HR, and sleep combined into one verdict
- **Personal baseline** — compares today against your own rolling average (not population norms)
- **Weekly training plan** — tap each day to cycle between Rest / Light / Workout
- **Primary CTA** — a lime pill button ("START WORKOUT" / "GO LIGHT" / "REST TODAY") that adapts to your readiness state
- **Quick Recovery carousel** — swipeable cards: Breathe (5-min guided breathing) and Quick Mobility (8-min session); more coming soon
- **Macro targets** — Mifflin-St Jeor BMR + activity multiplier + deficit/surplus
- **Steps & nutrition rings** — circular progress rings for steps, calories, and protein with real-time HealthKit data
- **AI food scanner** — photograph a meal, Claude estimates macros; review and log in one tap
- **Manual food log** — enter macros by hand when no photo is available
- **Evening check-out** — 3-step end-of-day flow (energy → mood → affirmation); confetti + haptics for hitting all 3 pillars (steps / protein / active kcal)
- **Day Closed card** — hero card switches to a calm closed state after check-out; shows today's key stats plus tomorrow's plan type
- **Notifications (Moderate)** — 3 daily reminders (morning · afternoon · evening) + a once-per-day recovery alert when readiness is yellow or red
- **Weight tracking** — set a goal weight, track progress, HealthKit or manual entry
- **Trend charts** — 7-day history for HRV, RHR, and sleep with color-coded data points
- **Profile** — name, photo, height, age, sex, training days, training location
- **Adjustable thresholds** — tune the scoring to match how your body responds
- **Dark-only UI** — purpose-built dark palette; no light mode
- **Fully local** — no account, no backend, no data leaves your phone (API calls go directly to Anthropic for food scans; your API key, your cost)

---

## How the scoring works

Each metric is scored against your personal rolling baseline:

| Metric | Good (+1) | Neutral (0) | Poor (−1) |
|--------|-----------|-------------|-----------|
| HRV (higher = better) | ≥ 95% of baseline | ≥ 80% of baseline | < 80% of baseline |
| Resting HR (lower = better) | ≤ 103% of baseline | ≤ 108% of baseline | > 108% of baseline |
| Sleep | ≥ target (default 7.5 h) | ≥ 6 h | < 6 h |

Total score −3 to +3 → verdict:
- **≥ 2** → Ready
- **0–1** → Go Light
- **≤ −1** → Rest Day

---

## Requirements

- iPhone running **iOS 17** or later
- **Must run on a real device** — HealthKit does not work in the Simulator
- Apple Watch recommended for HRV and resting HR (iPhone can still record RHR)
- Anthropic API key required for the AI food scanner (free tier available)

---

## Getting started

```bash
git clone git@github.com:micbou80/fitreadyapp.git
open fitreadyapp/FitReady.xcodeproj
```

1. In Xcode, select your iPhone as the run destination
2. Set your development team in **Signing & Capabilities** (your personal Apple ID is fine)
3. Hit **Run** (⌘R)
4. On first launch, grant HealthKit access and notification permission when prompted
5. Open **Settings → AI Scanner** and paste your Anthropic API key to enable food scanning

> Note: the bundle ID is `com.fitready.test` — change it if you want to use your own provisioning profile.

---

## Project structure

```
FitReady/
  FitReadyApp.swift                 ← app entry point, requests HealthKit + notification auth
  ContentView.swift                 ← tab bar (Today / Insights / Profile / Food / Settings)
  Models/
    DailyMetrics.swift              ← date + HRV + RHR + sleep hours
    ReadinessScore.swift            ← ReadinessVerdict enum + ReadinessScore struct
    TodayModels.swift               ← TodayAction, TodayTip, pillar model
    MealEntry.swift                 ← Codable meal log entry (name, kcal, macros, source)
    DailyCheckOut.swift             ← evening check-out entry; affirmation copy; AppStorage helpers
  Services/
    HealthKitManager.swift          ← all HealthKit queries (async/await), @MainActor
    ReadinessEngine.swift           ← pure scoring logic, no side effects
    MacroEngine.swift               ← Mifflin-St Jeor BMR + macro calculation
    AnthropicService.swift          ← Claude vision API call for food scanning
    NotificationManager.swift       ← local notification scheduling (moderate tier)
  Theme/
    AppColors.swift                 ← single source of truth for all app colors (dark-mode aware)
    DesignTokens.swift              ← DS.Spacing, DS.Corner, DS.Typography, etc.
  Views/
    Today/
      TodayView.swift               ← V2 Today screen, hosts sub-sections
      TodayViewModel.swift          ← @MainActor ObservableObject for Today state
      TodayHeroSection.swift        ← hero card: verdict + primary CTA pill + ghost secondary
      PrimaryActionSection.swift    ← legacy stub (superseded by TodayHeroSection)
      SecondaryActionsSection.swift ← secondary action chips
      RecoveryCarouselSection.swift ← horizontal quick recovery carousel
      QuickRecoveryCard.swift       ← compact recovery card
      CollapsedStatusSection.swift  ← steps + kcal + protein progress rings
      WeekCalendarStrip.swift       ← Mon–Sun training plan strip
      ReinforcementSection.swift    ← motivational reinforcement card
      ReadinessDetailsSheet.swift   ← full metric breakdown sheet
    Components/
      ReadinessRingView.swift       ← animated circular ring
      MetricCardView.swift          ← reusable HRV / RHR / Sleep card
      WeightCardView.swift          ← weight progress bar (current → goal)
      BodyFatCardView.swift         ← body fat % card
      MacroSummaryCard.swift        ← daily macro progress bars
      PrimaryCTAButton.swift        ← pill CTA: uppercased heavy label + chevron.right
      FoodScannerSheet.swift        ← photo picker + Claude analysis + review + log
      MiniRing.swift                ← small ring used in reinforcement section
      SoftCard.swift                ← card container (raised bg + 1pt border, no shadow)
      StatusChip.swift              ← small status badge
      HapticsManager.swift          ← UIImpactFeedbackGenerator wrapper
    BreathingExerciseView.swift     ← 5-min guided breathing full-screen
    EveningCheckOutView.swift       ← 3-step check-out flow + Canvas confetti
    FoodView.swift                  ← Food tab: macro rings + meal log + scanner
    HistoryView.swift               ← Insights tab: 7-day trend charts
    MenuAdvisorView.swift           ← AI meal advisor by readiness state
    ProfileView.swift               ← Profile hub (navigate to sub-views)
    PersonalSettingsView.swift      ← name, photo, height, age, sex, units
    GoalsView.swift                 ← primary goal, weekly pace, macro calculation
    NotificationsView.swift         ← notification level preference
    RecoveryWorkoutView.swift       ← 7-min guided mobility session
    SettingsView.swift              ← thresholds, baseline window, sleep target, API key
    MainReadinessView.swift         ← V1 Today screen (preserved for comparison)
```

---

## Roadmap

- [ ] Workout logging (tap-to-log sets/reps, auto-progression)
- [ ] Training templates (Full Body / Upper-Lower / Push-Pull-Legs)
- [ ] Onboarding flow
- [ ] Daily momentum score (2/3 pillars = success, not streaks)
- [ ] WatchOS companion app (readiness glance, quick log)
- [ ] Subscriptions

---

## Tech

- **SwiftUI** — UI throughout, no UIKit except camera picker and haptics
- **HealthKit** — read-only (HRV SDNN, Resting HR, Sleep Analysis, Body Mass, Active Energy, Steps, Dietary data)
- **Swift Charts** — built-in, no third-party packages
- **Anthropic API** — `claude-sonnet-4-6` vision for food scanning (user-supplied key)
- **@AppStorage** — all settings persisted via UserDefaults, no CoreData
- **Dark-only** — locked via `preferredColorScheme(.dark)`; 16-token color system in `AppColors.swift`
- **No third-party packages, no backend, no account required**
