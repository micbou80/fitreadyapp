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
- **Personal baseline** — compares today against your own 7-day rolling average (not population norms)
- **Trend charts** — 7-day history for each metric with color-coded data points
- **Weight tracking** — set a goal weight, track progress against it
- **Adjustable thresholds** — tune the scoring to match how your body responds
- **Fully local** — no account, no backend, no data leaves your phone

---

## How the scoring works

Each metric is scored against your personal 7-day baseline:

| Metric | Good (+1) | Neutral (0) | Poor (−1) |
|--------|-----------|-------------|-----------|
| HRV (higher = better) | ≥ 95% of baseline | ≥ 80% of baseline | < 80% of baseline |
| Resting HR (lower = better) | ≤ 103% of baseline | ≤ 108% of baseline | > 108% of baseline |
| Sleep | ≥ target (default 7.5h) | ≥ 6h | < 6h |

Total score −3 to +3 → verdict:
- **≥ 2** → Ready
- **0–1** → Go Light
- **≤ −1** → Rest Day

---

## Requirements

- iPhone running **iOS 17** or later
- **Must run on a real device** — HealthKit does not work in the Simulator
- Apple Watch recommended (for HRV and resting HR data — though iPhone can record RHR too)

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

> Note: the bundle ID is `com.fitready.test` — change it to something unique if you want to use your own provisioning.

---

## Project structure

```
FitReady/
  FitReadyApp.swift              ← app entry point, requests HealthKit auth
  ContentView.swift              ← tab bar (Today / Trends / Profile / Settings)
  Models/
    DailyMetrics.swift           ← date + HRV + RHR + sleep hours
    ReadinessScore.swift         ← verdict enum and computed score
  Services/
    HealthKitManager.swift       ← all HealthKit queries (async/await)
    ReadinessEngine.swift        ← pure scoring logic, no side effects
  Views/
    MainReadinessView.swift      ← today screen: ring + metric cards + weight
    HistoryView.swift            ← 7-day trend charts per metric
    ProfileView.swift            ← set goal weight, manual weight entry
    SettingsView.swift           ← thresholds, baseline window, sleep target
    Components/
      ReadinessRingView.swift    ← animated ring indicator
      MetricCardView.swift       ← HRV / RHR / Sleep card
      WeightCardView.swift       ← weight progress bar (current → goal)
```

---

## Roadmap

- [ ] Workout logging (tap-to-log sets/reps, auto-progression)
- [ ] Training templates (Full Body / Upper-Lower / Push-Pull-Legs)
- [ ] Nutrition logging via photo (Claude API for macro estimation)
- [ ] Onboarding flow
- [ ] Daily momentum score
- [ ] WatchOS companion app

---

## Tech

- **SwiftUI** — UI, no UIKit
- **HealthKit** — read-only (HRV, Resting HR, Sleep Analysis, Body Mass)
- **Swift Charts** — built-in, no packages
- **@AppStorage** — all settings persisted via UserDefaults
- **No packages, no backend, no account required**
