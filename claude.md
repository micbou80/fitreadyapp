# CLAUDE.md — FitReady

This file is the single source of truth for both product vision and technical context.
Update it as decisions are made. Claude Code reads this on every session.

---

## Product Vision

### Core Promise
> In under 10 seconds per day, tell the user what to do to stay on track with their health — without stress, complexity, or guilt.

### Core Emotional Outcome
Every interaction must leave the user feeling:
- "I'm doing okay"
- "I know what to do next"
- "I'm making progress"

### Positioning
This is NOT a calorie tracker, workout library, or hardcore coaching app.
This IS: **a calm, adaptive daily decision system for health and fitness.**

### Core Principles (Non-Negotiable)
1. Clarity over complexity
2. Guidance over control
3. Consistency over perfection
4. Progress over precision
5. Calm over pressure

### UX Rules
- <3 seconds to understand today's state
- <60 seconds to log a workout
- <10 seconds to log a meal
- No tutorials. No friction. No punishment.

### Tone
Always calm, supportive, short, non-judgmental.

| Avoid | Use instead |
|-------|-------------|
| "You failed" | "Slight adjustment" |
| "Missed workout" | "Pick it up tomorrow" |
| "Over calories" | "Balance tomorrow" |

---

## Current Build State

The app is in early MVP stage: **readiness scoring + weight tracking only.**
No workout logging, nutrition, or training system yet (planned — see Roadmap).

### What works today
- HealthKit reads: HRV (SDNN), Resting HR, Sleep Analysis, Body Mass
- 7-day rolling baseline per metric
- Readiness verdict: Ready / Go Light / Rest Day
- History charts (7 days, Swift Charts)
- Settings: baseline days, sleep target, HRV/RHR thresholds
- Profile: weight goal, manual weight entry or HealthKit auto
- Weight card on Today screen (current → goal progress bar)

---

## Technical Stack

| Layer | Choice |
|-------|--------|
| Platform | iOS 17+, Swift, SwiftUI |
| Data | HealthKit (read-only), `@AppStorage` / UserDefaults |
| Charts | Swift Charts (built-in, no packages) |
| Backend | None (fully local) |
| AI | Not integrated yet (planned for food logging) |
| Future | WatchOS, SwiftData, Claude API (Haiku/Sonnet) |

---

## Project Structure

```
FitReady/
  FitReadyApp.swift              ← @main, requests HealthKit auth on launch
  ContentView.swift              ← TabView: Today | Trends | Profile | Settings
  Models/
    DailyMetrics.swift           ← struct: date, hrv?, rhr?, sleepHours?
    ReadinessScore.swift         ← ReadinessVerdict enum + ReadinessScore struct
  Services/
    HealthKitManager.swift       ← all HK queries (async/await), @MainActor ObservableObject
    ReadinessEngine.swift        ← pure scoring logic, AppSettings struct
  Views/
    MainReadinessView.swift      ← Today tab: ring + metric cards + weight card
    HistoryView.swift            ← Trends tab: 3 Swift Charts line charts
    ProfileView.swift            ← Profile tab: weight goal + manual weight entry
    SettingsView.swift           ← Settings tab: thresholds, baseline days, sleep target
    Components/
      ReadinessRingView.swift    ← animated circular ring (AngularGradient, spring)
      MetricCardView.swift       ← reusable HRV / RHR / Sleep card
      WeightCardView.swift       ← weight progress card (current → goal bar)
```

---

## Key Technical Decisions

### HealthKit
- Authorization requested at launch in `FitReadyApp.swift`
- Read types: HRV SDNN, Resting HR, Sleep Analysis, Body Mass
- All queries use `async/await` via `withCheckedContinuation`
- `HealthKitManager` is `@MainActor final class` injected as `@EnvironmentObject`
- Sleep window: 6pm → noon next day (catches naps and late nights)
- Refresh on foreground via `NotificationCenter` + `UIApplication.willEnterForegroundNotification`

### Scoring Algorithm (ReadinessEngine)
Each metric scored -1 / 0 / +1 vs. 7-day rolling average:

| Metric | Good (+1) | Neutral (0) | Poor (-1) |
|--------|-----------|-------------|-----------|
| HRV (higher=better) | ≥ baseline × 0.95 | ≥ baseline × 0.80 | < baseline × 0.80 |
| RHR (lower=better) | ≤ baseline × 1.03 | ≤ baseline × 1.08 | > baseline × 1.08 |
| Sleep | ≥ target hrs | ≥ 6.0 hrs | < 6.0 hrs |

Total score -3 to +3 → verdict:
- ≥ 2 → Ready (green)
- 0–1 → Go Light (orange)
- ≤ -1 → Rest Day (red)

### Persistence
- All user settings via `@AppStorage` (UserDefaults) — no CoreData yet
- Keys in use: `baselineDays`, `sleepTargetHours`, `hrvGoodThreshold`, `hrvNeutralThreshold`, `rhrGoodThreshold`, `rhrNeutralThreshold`, `goalWeightKg`, `manualWeightKg`, `useManualWeight`

### Xcode Project
- Project file: manually maintained `project.pbxproj`
- UUIDs must be exactly **24 hex characters** (prefix `BF000000000000000000...`)
- Next available build file UUID: `BF0000000000000000000011`
- Next available file reference UUID: `BF0000000000000000000034`
- When adding a new Swift file, add entries in **four** places in pbxproj:
  1. `PBXBuildFile` section
  2. `PBXFileReference` section
  3. The relevant `PBXGroup` children list
  4. `PBXSourcesBuildPhase` files list

---

## Device & Build Config

| Setting | Value |
|---------|-------|
| Bundle ID | `com.fitready.test` |
| Development Team | `U7BG3FD65B` (Michel Bouman) |
| Device | iPhone18,2, iOS 26.4 (beta) |
| Xcode | 26.3 |
| Entitlement | `com.apple.developer.healthkit = true` (basic only — no Verifiable Health Records) |
| Minimum deployment | iOS 17.0 |

**Important:** Do NOT add `com.apple.developer.healthkit.background-delivery` or `com.apple.developer.healthkit.recalibrate-estimates` — personal team provisioning rejects them.

---

## Repo & Git

- GitHub: `git@github.com:micbou80/fitreadyapp.git`
- Branch: `main`
- SSH key configured at `~/.ssh/id_ed25519_github`
- Working directory: `/Users/micbou/Library/Mobile Documents/com~apple~CloudDocs/Claude/FitReady/fitreadyapp`
- After committing, push with: `git push origin main`

---

## Roadmap (Planned Features)

In rough priority order:

1. **Workout logging** — pre-filled sessions, tap-to-log reps/sets, auto-progression (e1RM)
2. **Training templates** — Full Body (2–3d), Upper/Lower (4d), PPL (5d+)
3. **Nutrition logging** — photo-first, Claude API for macro estimation (ranges not exact)
4. **Onboarding flow** — goal, training days, gym type, HealthKit connect
5. **Daily summary / momentum score** — 2/3 pillars = success, not streaks
6. **WatchOS companion** — readiness glance, workout log
7. **Subscriptions** — €7.99/mo or €59/yr, 7-day trial

### AI Strategy (when added)
- Claude Haiku: food photo estimation, quick responses
- Claude Sonnet: weekly summaries, coaching insights
- **Never use AI for:** readiness scoring, progression logic, daily decisions (keep those deterministic)
- Food prompt returns JSON with calorie range + protein range + confidence
- Target AI cost: €1–2 per user/month — cache aggressively

---

## What Will Kill This App

- Too many features at once
- Exact numbers instead of ranges/guidance
- Any UX that makes users feel judged or guilty
- Breaking the <3 second comprehension rule on the Today screen

---

## Definition of Success

> After a bad day, the user opens the app and feels: "I'm okay, let's keep going."
> If not — redesign immediately.
