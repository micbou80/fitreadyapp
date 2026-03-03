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
- **Weekly training plan** — tap each day to cycle between Rest / Run / Workout
- **Macro targets** — Mifflin-St Jeor BMR + activity multiplier + deficit/surplus
- **AI food scanner** — photograph a meal, Claude estimates macros; review and log in one tap
- **Manual food log** — enter macros by hand when no photo is available
- **Weight tracking** — set a goal weight, track progress, HealthKit or manual entry
- **Trend charts** — 7-day history for HRV, RHR, and sleep with color-coded data points
- **Profile** — name, photo, height, age, sex, training days, training location
- **Adjustable thresholds** — tune the scoring to match how your body responds
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
4. On first launch, grant HealthKit access when prompted
5. Open **Settings → AI Scanner** and paste your Anthropic API key to enable food scanning

> Note: the bundle ID is `com.fitready.test` — change it if you want to use your own provisioning profile.

---

## Project structure

```
FitReady/
  FitReadyApp.swift                 ← app entry point, requests HealthKit auth
  ContentView.swift                 ← tab bar (Today / Insights / Profile / Food / Settings)
  Models/
    DailyMetrics.swift              ← date + HRV + RHR + sleep hours
    ReadinessScore.swift            ← ReadinessVerdict enum + ReadinessScore struct
    TodayModels.swift               ← TodayAction, TodayTip, pillar model
    MealEntry.swift                 ← Codable meal log entry (name, kcal, macros, source)
  Services/
    HealthKitManager.swift          ← all HealthKit queries (async/await), @MainActor
    ReadinessEngine.swift           ← pure scoring logic, no side effects
    MacroEngine.swift               ← Mifflin-St Jeor BMR + macro calculation
    AnthropicService.swift          ← Claude vision API call for food scanning
  Theme/
    AppColors.swift                 ← single source of truth for all app colors (dark-mode aware)
    DesignTokens.swift              ← DS.Spacing, DS.Corner, DS.Typography, etc.
  Views/
    Today/
      TodayView.swift               ← decision-first Today screen (V2)
      TodayViewModel.swift          ← @MainActor ObservableObject for Today state
      TodayHeroSection.swift        ← readiness ring + verdict header
      PrimaryActionSection.swift    ← main CTA (train / run / rest)
      SecondaryActionsSection.swift ← secondary action chips
      CollapsedStatusSection.swift  ← collapsed metric + macro status bar
      WeekCalendarStrip.swift       ← Mon–Sun training plan strip
      ReinforcementSection.swift    ← motivational reinforcement card
      ReadinessDetailsSheet.swift   ← full metric breakdown sheet
    Components/
      ReadinessRingView.swift       ← animated circular ring
      MetricCardView.swift          ← reusable HRV / RHR / Sleep card
      WeightCardView.swift          ← weight progress bar (current → goal)
      BodyFatCardView.swift         ← body fat % card
      MacroSummaryCard.swift        ← daily macro progress rings
      PrimaryCTAButton.swift        ← full-width action button
      FoodScannerSheet.swift        ← photo picker + Claude analysis + review + log
      MiniRing.swift                ← small ring used in reinforcement section
      SoftCard.swift                ← reusable card container
      StatusChip.swift              ← small status badge
      HapticsManager.swift          ← UIImpactFeedbackGenerator wrapper
    FoodView.swift                  ← Food tab: macro rings + meal log + scanner
    HistoryView.swift               ← Insights tab: 7-day trend charts
    ProfileView.swift               ← Profile hub (navigate to sub-views)
    PersonalSettingsView.swift      ← name, photo, height, age, sex, units
    GoalsView.swift                 ← primary goal, weekly pace, macro calculation
    NotificationsView.swift         ← notification level preference
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

- **SwiftUI** — UI throughout, no UIKit except camera picker wrapper
- **HealthKit** — read-only (HRV SDNN, Resting HR, Sleep Analysis, Body Mass, Active Energy, Steps, Dietary data)
- **Swift Charts** — built-in, no third-party packages
- **Anthropic API** — `claude-sonnet-4-6` vision for food scanning (user-supplied key)
- **@AppStorage** — all settings persisted via UserDefaults, no CoreData
- **No third-party packages, no backend, no account required**
