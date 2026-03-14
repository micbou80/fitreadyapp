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

The app has a complete Today experience, food logging with AI scanning, macro targets, weight
tracking, and a full profile system.

### What works today

**Readiness**
- HealthKit reads: HRV (SDNN), Resting HR, Sleep Analysis, Body Mass, Active Energy, Steps,
  Dietary Calories / Protein / Fat / Carbs
- 7-day rolling personal baseline per metric
- Readiness verdict: Ready / Go Light / Rest Day
- Full metric breakdown sheet (tap the ring)
- History charts (7 days, Swift Charts)
- Settings: baseline days, sleep target, HRV/RHR thresholds

**Food & Nutrition**
- AI food scanner: photograph a meal → Claude estimates macros → user reviews → taps Log
- Manual macro entry (daily total fallback)
- Per-meal log stored in `mealsJSON` AppStorage; swipe to delete
- Macro target calculation (Mifflin-St Jeor BMR, activity level, deficit/surplus pace)
- HealthKit dietary data takes priority over scanned/manual entries when available
- Anthropic API key stored in `anthropicAPIKey` AppStorage, entered in Settings

**Evening check-out**
- 3-step flow (Energy → Mood → Affirmation) triggered after 9 pm, locked per calendar day
- Day signals card: Steps, Calories, Protein (🥚), Active kcal — each with hit/miss indicator
- Celebration tiers on final screen: confetti + decrescendo haptics (3 pillars) / high-five icon + lighter haptics (2) / haptic only (1) / encouragement (0)
- Personalised affirmation title (uses profile name) + second-person body copy
- Caloric balance pill (green = deficit/on-target, amber = surplus)
- Stored as `DailyCheckOut` in `checkOutsJSON` AppStorage (capped to 30 entries)
- Pillars: `stepsHit` ≥ 10k, `proteinHit` ≥ 90% target, `activeHit` ≥ 300 kcal

**Day Closed hero card**
- `TodayHeroSection` switches to green-tinted closed state after check-out until midnight
- Shows affirmation title + body from `DailyCheckOut`
- Single-row mini stats: 🚶 steps · 🥚 protein · ⚡ kcal · ➖ deficit
- Tomorrow type signal (Train / Light / Rest) from weekly plan

**Profile**
- Name, profile photo, height, age, biological sex, training days/week, training location, units (metric/imperial)
- Primary goal (lose / maintain / gain / build muscle) and weekly pace
- Notification level preference
- Dev reset button (resets `lastCheckOutDate` + opens check-out preview)

**Notifications (Moderate tier)**
- `NotificationManager` singleton in `Services/`
- Moderate = 3 daily repeating reminders (7:30 am, 3:00 pm, 9:00 pm) + once-per-day recovery alert
- Recovery alert fires in-app when readiness is yellow or red (uses `recoveryAlertSent_yyyy-MM-dd` UserDefaults key to gate once/day)
- Permission requested on first app launch alongside HealthKit
- Other tiers (everything / light / affirmations / off) defined in `NotificationsView` UI but not yet implemented

**Today screen (V2)**
- Decision-first layout: hero card (verdict + CTAs) → quick recovery carousel → week strip → steps/nutrition status
- Hero card (`TodayHeroSection`): readiness chip + headline + reason + "See details" + primary CTA pill + ghost "Log a meal" pill
- Primary CTA (`PrimaryCTAButton`): lime pill, uppercased heavy label, chevron.right right-aligned; 120ms press animation with scale(0.97) + brightness(−0.10)
- Secondary "Log a meal" button: ghost pill with 1pt border, no fill
- Quick Recovery carousel (`RecoveryCarouselSection`): horizontal scroll — Breathe (5 min) + Quick Mobility (8 min) live; Cold Splash + Focus Sound locked/coming soon
- Weekly training plan: tap each day to cycle Rest / Light / Workout
- Reinforcement card (motivational, adapts to readiness state)
- CollapsedStatusSection: Steps + kcal + protein each with circular progress ring; track = `metricInactive`, fill = `metricActive`

**V1 Today screen** (`MainReadinessView.swift`) is preserved for comparison. Not in the active tab bar.

---

## Technical Stack

| Layer | Choice |
|-------|--------|
| Platform | iOS 17+, Swift, SwiftUI |
| Data | HealthKit (read-only), `@AppStorage` / UserDefaults |
| Charts | Swift Charts (built-in) |
| Backend | None — fully local |
| AI | Anthropic API (`claude-sonnet-4-6`) for food scanning |
| Future | WatchOS, SwiftData, workout logging |

---

## Project Structure

```
FitReady/
  FitReadyApp.swift                 ← @main, requests HealthKit auth on launch
  ContentView.swift                 ← TabView: Today | Insights | Profile | Food | Settings
  Models/
    DailyMetrics.swift              ← struct: date, hrv?, rhr?, sleepHours?
    ReadinessScore.swift            ← ReadinessVerdict enum + ReadinessScore struct
    TodayModels.swift               ← TodayAction, TodayTip, pillar structs
    MealEntry.swift                 ← Codable meal log entry (id, date, name, macros, source)
    DailyCheckOut.swift             ← Codable check-out entry; affirmation copy; AppStorage helpers
  Services/
    HealthKitManager.swift          ← all HK queries (async/await), @MainActor ObservableObject
    ReadinessEngine.swift           ← pure scoring logic, AppSettings struct
    MacroEngine.swift               ← Mifflin-St Jeor BMR + macro targets computation
    AnthropicService.swift          ← POST /v1/messages with vision, returns FoodScanResult
    NotificationManager.swift       ← UNUserNotificationCenter singleton; schedules moderate tier
  Theme/
    AppColors.swift                 ← single source of truth for ALL colors (dark-mode adaptive)
    DesignTokens.swift              ← DS.Spacing, DS.Corner, DS.Typography, DS.Shadow — delegates to AppColors
  Views/
    Today/
      TodayView.swift               ← V2 Today screen, hosts sub-sections
      TodayViewModel.swift          ← @MainActor ObservableObject, orchestrates Today state
      TodayHeroSection.swift        ← hero card: verdict chip + headline + primary CTA pill + ghost secondary
      PrimaryActionSection.swift    ← legacy stub (superseded by TodayHeroSection CTAs)
      SecondaryActionsSection.swift ← secondary action chips row
      RecoveryCarouselSection.swift ← horizontal quick recovery card carousel (Breathe · Mobility · locked)
      QuickRecoveryCard.swift       ← compact recovery card used in carousel
      CollapsedStatusSection.swift  ← steps + kcal + protein rings (track = metricInactive)
      WeekCalendarStrip.swift       ← Mon–Sun training plan picker
      ReinforcementSection.swift    ← motivational reinforcement card
      ReadinessDetailsSheet.swift   ← full metric breakdown sheet
      TomorrowSignalSection.swift   ← tomorrow plan type signal
    Components/
      ReadinessRingView.swift       ← animated ring (AngularGradient, spring)
      MetricCardView.swift          ← reusable HRV / RHR / Sleep card
      WeightCardView.swift          ← weight progress card (current → goal bar)
      BodyFatCardView.swift         ← body fat % card
      MacroSummaryCard.swift        ← daily macro progress bars (metricActive fill, metricInactive track)
      PrimaryCTAButton.swift        ← lime/amber/red pill CTA; uppercased heavy label + chevron.right
      FoodScannerSheet.swift        ← camera/library picker + Claude analysis + review + log
      MiniRing.swift                ← small ring for reinforcement section
      SoftCard.swift                ← reusable card container (raised bg + 1pt border, no shadow)
      StatusChip.swift              ← small status badge chip
      HapticsManager.swift          ← UIImpactFeedbackGenerator + UINotificationFeedbackGenerator wrapper
    BreathingExerciseView.swift     ← 5-min guided breathing full-screen (3s in · 4s out loop)
    EveningCheckOutView.swift       ← 3-step check-out flow + ConfettiView (file-private)
    FoodView.swift                  ← Food tab: macro rings, meal log list, scanner/manual entry
    HistoryView.swift               ← Insights tab: 7-day line charts for HRV / RHR / Sleep
    MenuAdvisorView.swift           ← AI-powered meal suggestions by readiness state
    ProfileView.swift               ← Profile hub, navigates to sub-views; dev reset button
    PersonalSettingsView.swift      ← name, photo, height, age, sex, training days/location, units
    GoalsView.swift                 ← primary goal, pace, goal targets (weight/fat%/date), Personalize My Plan → PlanSplashView
    NotificationsView.swift         ← notification level preference selector
    RecoveryWorkoutView.swift       ← 7-min guided mobility session (step-by-step)
    SettingsView.swift              ← thresholds, baseline window, sleep target, AI scanner API key
    MainReadinessView.swift         ← V1 Today screen (preserved, NOT in tab bar)
```

---

## Key Technical Decisions

### HealthKit
- Authorization requested at launch in `FitReadyApp.swift`
- Read types: HRV SDNN, Resting HR, Sleep Analysis, Body Mass, Active Energy, Steps,
  Dietary Energy / Protein / Fat / Carbs
- All queries use `async/await`
- `HealthKitManager` is `@MainActor final class` injected as `@EnvironmentObject`
- Sleep window: 6 pm → noon next day (catches naps and late nights)
- Refresh on foreground via `NotificationCenter` + `UIApplication.willEnterForegroundNotification`

### Scoring Algorithm (ReadinessEngine)
Z-score methodology — accounts for personal variability rather than fixed ratios.

**HRV (28-day rolling baseline):**
`z = (today_HRV − avg28) / sd28` (nil if <3 samples available)

**RHR (7-day rolling baseline):**
`delta = today_RHR − avg7` in bpm (nil if no data)

**Combined verdict:**
| Condition | Verdict |
|-----------|---------|
| z > −0.5 AND delta < +3 bpm | Ready |
| z < −1.5 OR delta > +5 bpm | Rest |
| Everything else | Light |

**Sleep modifier:** if sleep < 6 h, downgrade verdict one level (Ready → Light, Light → Rest)

**Ring display:** z clamped to [−2, +2] → mapped to 0–100%; falls back to verdict fixed value when z is nil
**UX rule:** never show raw z-scores to the user — translate to "Ready to Train" / "Normal Day" / "Recovery Recommended"

**Baseline windows:**
- HRV: 28-day (monthly, stable autonomic baseline) — `ReadinessEngine.hrvBaselineDays`
- RHR: 7-day slice of same baseline array — `ReadinessEngine.rhrBaselineDays`

### Macro Calculation (MacroEngine)
1. Mifflin-St Jeor BMR (weight, height, age, sex)
2. × activity multiplier (sedentary 1.2 → very active 1.725)
3. − weekly deficit (0.25 / 0.5 / 0.75 kg/wk = −275 / −550 / −825 kcal/day); positive = surplus
4. Protein: `weightKg × proteinPerKg` (default 1.8 g/kg)
5. Fat: max of `fatFloorPct`% of total kcal (default 25%) or 0.8 g/kg
6. Carbs: remaining kcal ÷ 4

### AI Food Scanner (AnthropicService)
- Model: `claude-sonnet-4-6` (vision, best cost/accuracy balance)
- Image: resized to max 1024 px longest side, JPEG @ 0.8 → base64
- Prompt: system instructs nutrition analyst; user sends image + portion size (S/M/L)
- Response format: JSON `{ meal_name, kcal, protein_g, fat_g, carbs_g }`
- API key stored in `anthropicAPIKey` AppStorage; user enters it in Settings

### Color System (AppColors)
`FitReady/Theme/AppColors.swift` is the **only** place colors are defined. All other files use
`AppColors.<token>`. Never add hardcoded `Color(red:...)`, hex literals, or SwiftUI system color
names (`.purple`, `.blue`, etc.) anywhere else. The app follows the **device light/dark setting**
(no `preferredColorScheme` lock). Surface/text tokens adapt; brand and card tokens are fixed.
Cards use `.background(.ultraThinMaterial)` — text adapts naturally via the adaptive color tokens.

**Color token palette (★ = adaptive dark/light):**

| Token | Dark hex | Light hex | Usage |
|-------|----------|-----------|-------|
| `brandPrimary` ★ | #D4FF3F | #C7F22B | ActionLime — primary CTA bg, active metric fill, icons |
| `brandDark` | #B4E01F | — (fixed) | ActionLimePressed — hover / pressed tint |
| `brandMuted` ★ | #0F1B0C | #24361F | DeepMoss — hero tint, structural depth |
| `sage` | #8FAF8A | — (fixed) | SageGreen — success states, completed activities |
| `bg` ★ | #11140F | #F6F7F2 | page / screen background |
| `surface` ★ | #1A1D16 | #EAEAE5 | inset surfaces, picker backgrounds |
| `raised` | #24361F | — (fixed) | DeepMoss card bg — **always dark, never changes** |
| `border` ★ | #3A4030 | #D0D4C8 | card borders, dividers, ghost button strokes |
| `textPrimary` ★ | #F7F8F3 | #111111 | primary readable text |
| `textSecondary` ★ | #9AA88C | #5F665C | labels, captions, supporting text |
| `textMuted` ★ | #5C6652 | #858F78 | disabled, placeholder, very subtle |
| `textOnBrand` | #0D0F0B | — (fixed) | text on lime / amber fills |
| `warning` | #E3A23A | — (fixed) | AmberNudge — Go Light state, nutrition nudges |
| `danger` | #C97A52 | — (fixed) | TerracottaAlert — Rest Day state, significant imbalance |
| `info` | #4DA6FF | — (fixed) | sleep metric, informational |
| `metricActive` | (= brandPrimary) | — | progress ring/bar fill |
| `metricInactive` | #24361F | — (fixed) | progress ring/bar track (DeepMoss, inside dark cards) |
| `dataProtein` | #B6D94C | — | ProteinSage — protein category |
| `dataCarbs` | #78B7F2 | — | CarbAzure — carbs category |
| `dataFat` | #E07A6A | — | FatCoral — fat category |
| `dataCalories` | #E9B44C | — | CalorieAmber — calorie category |

**Glass tinting rules (Liquid Glass spec):**
- Hero / readiness panels: `brandPrimary.opacity(0.08)` behind `.ultraThinMaterial` (GlassTintGreen)
- Standard cards: `.ultraThinMaterial` only (SoftCard)
- Tint intensity must stay 6–10% opacity max

**One bright action rule:** Only ONE filled `brandPrimary` element per screen. All other CTAs use ghost/outline style.

**Design system rules:**
- Cards: `.ultraThinMaterial` bg + 1pt `border` overlay + `DS.Shadow` (0.05 opacity, radius 10)
- CTAs: `brandPrimary` bg + `textOnBrand` text (lime); `warning` bg + `textOnBrand` (amber); `danger` bg + `textPrimary` (red)
- Progress rings: `metricActive` fill, `metricInactive` track
- Recovery card icons: `brandMuted` bg + `brandPrimary` icon (active cards)

### Persistence (AppStorage Keys)
All settings live in UserDefaults via `@AppStorage`. No CoreData.

| Key | Type | Default | Purpose |
|-----|------|---------|---------|
| `baselineDays` | Int | 7 | Rolling baseline window |
| `sleepTargetHours` | Double | 7.5 | Sleep scoring target |
| `hrvGoodThreshold` | Double | 0.95 | HRV good threshold (ratio) |
| `hrvNeutralThreshold` | Double | 0.80 | HRV neutral threshold |
| `rhrGoodThreshold` | Double | 1.03 | RHR good threshold |
| `rhrNeutralThreshold` | Double | 1.08 | RHR neutral threshold |
| `goalWeightKg` | Double | 0 | Goal weight (same key used by weight card + GoalsView) |
| `goalBodyFatPct` | Double | 0 | Target body fat % |
| `goalTargetDateTS` | Double | 0 | Target date as TimeInterval (0 = not set) |
| `manualWeightKg` | Double | 0 | Manual weight override |
| `useManualWeight` | Bool | false | Prefer manual weight over HealthKit |
| `useImperial` | Bool | false | Show lbs/ft instead of kg/cm |
| `profileName` | String | "" | User's name |
| `profilePhotoData` | Data | Data() | Profile photo JPEG |
| `profileBirthdayTS` | Double | 0 | Birthday as TimeInterval |
| `heightCm` | Double | 0 | Height in cm |
| `ageYears` | Int | 0 | Age (derived from birthday or direct) |
| `biologicalSex` | String | "" | "male" or "female" |
| `trainingDaysPerWeek` | Int | 4 | Days/week for activity multiplier |
| `trainingLocation` | String | "gym" | "gym" or "home" |
| `activityLevel` | String | "moderate" | Activity multiplier key |
| `primaryGoal` | String | "lose" | "lose" / "maintain" / "gain" / "muscle" |
| `weightLossPace` | Double | 0.5 | kg/week deficit (negative = surplus) |
| `proteinPerKg` | Double | 1.8 | Protein target g/kg |
| `fatFloorPct` | Double | 25 | Fat floor as % of total kcal |
| `mealsJSON` | String | "[]" | JSON-encoded `[MealEntry]` (all dates) |
| `manualKcal` | Double | 0 | Manual daily kcal total (legacy) |
| `manualProteinG` | Double | 0 | Manual daily protein total (legacy) |
| `manualFatG` | Double | 0 | Manual daily fat total (legacy) |
| `manualCarbsG` | Double | 0 | Manual daily carbs total (legacy) |
| `manualMacroDate` | String | "" | Date key for manual entry (legacy) |
| `weeklyScheduleJSON` | String | "{}" | V1 weekly plan JSON (MainReadinessView) |
| `weeklyPlan` | String | "W,L,W,L,W,R,R" | V2 weekly plan comma-separated |
| `anthropicAPIKey` | String | "" | Anthropic API key for food scanner |
| `notificationLevel` | String | "moderate" | Notification preference (everything/moderate/light/affirmations/off) |
| `checkOutsJSON` | String | "[]" | JSON-encoded `[DailyCheckOut]`, capped to 30 entries |
| `lastCheckOutDate` | String | "" | `yyyy-MM-dd` of last completed check-out; gates once-per-day lock |
| `lastCheckOutMessage` | String | "" | Affirmation title from last check-out (fallback display) |

### Xcode Project (project.pbxproj)
- Manually maintained — no Swift Package Manager, no CocoaPods
- UUIDs are exactly **24 hex characters**, prefix `BF000000000000000000`
- **Next available build file UUID:** `BF00000000000000000000BD`
- **Next available file reference UUID:** `BF00000000000000000000BE`
- When adding a new Swift file, add entries in **four** places:
  1. `PBXBuildFile` section (build file UUID → file ref UUID)
  2. `PBXFileReference` section (file ref UUID → path)
  3. The relevant `PBXGroup` children array
  4. `PBXSourcesBuildPhase` files array
- Validate after every edit: `plutil -lint FitReady.xcodeproj/project.pbxproj`

---

## Device & Build Config

| Setting | Value |
|---------|-------|
| Bundle ID | `com.fitready.test` |
| Development Team | `U7BG3FD65B` (Michel Bouman) |
| Minimum deployment | iOS 17.0 |
| Entitlement | `com.apple.developer.healthkit = true` (basic only) |

**Important:** Do NOT add `com.apple.developer.healthkit.background-delivery` or
`com.apple.developer.healthkit.recalibrate-estimates` — personal team provisioning rejects them.

---

## Repo & Git

- GitHub: `git@github.com:micbou80/fitreadyapp.git`
- Branch: `main`
- SSH key: `~/.ssh/id_ed25519_github`
- Working directory: `/Users/micbou/Library/Mobile Documents/com~apple~CloudDocs/Claude/FitReady/fitreadyapp`
- Push: `GIT_SSH_COMMAND="ssh -i ~/.ssh/id_ed25519_github" git push origin main`
- Never commit `.DS_Store` or `*.xcuserstate`

### Changelog — mandatory

Every session that makes code changes must update `CHANGELOG.md` in the repo root before closing. Append a new entry at the top (newest first) using this format:

```
## YYYY-MM-DD — [short title]

### Added / Changed / Fixed
- What changed and why

### Notes
Any decisions, tradeoffs, or context future sessions need to know.
```

One entry per working session. Focus on *why*, not implementation detail. If something was tried and reverted, note it.

---

## Roadmap (Planned Features)

### 🪲 Bugs

- ~~**Elapsed time broken in background**~~ — fixed: timer now stores `startDate` on appear and computes `elapsed = now − startDate`; recomputes on `willEnterForeground`
- **Weight progression inconsistency** — weight jump suggestions between sessions are not consistent; review progression engine logic
- ~~**Profile photo crop sheet**~~ — fixed: removed `NavigationStack` from `CropImageSheet`; build chrome (X button, title) manually; added `.presentationBackground(Color.black)` on the root ZStack; crop + pan + zoom gestures unchanged
- **Home screen widget / Live Activity** — Dynamic Island or lock screen progress not yet implemented; investigate if feasible with personal team entitlements

### 🏋 Workout

- ~~**Adjust weights manually**~~ — fixed: tap the weight value in SetRow to open an inline TextField with decimal pad; commits on focus loss or keyboard Done
- **Adjust number of sets** — allow user to add or remove sets per exercise in the active workout
- **Effort-based progression** — capture RPE or effort signal after each set to determine the next session's advice
- **HealthKit write-back after workout** — decide what to write back (active energy, workout type, duration) and implement HKWorkout save
- **Add Walk as exercise type** — duration + incline/pace cardio entry, distinct from strength exercises
- **Card-swipe UI for workouts** — replace list with swipeable exercise cards during an active session
- **Reorder exercises in workout** — allow drag-to-reorder exercises within a session
- **End-of-workout summary card** — show a completion card after finishing: sets done, estimated kcal, progression highlights
- **NEAT link in end card** — clarify how the workout's active energy feeds into the NEAT / energy balance shown in Insights
- **Launch Apple Workout app** — evaluate whether triggering the native Workout app is needed or beneficial (Watch integration)
- **Workout logging** — pre-filled sessions, tap-to-log reps/sets, auto-progression (e1RM) ← core feature
- **Training templates** — Full Body (2–3d), Upper/Lower (4d), PPL (5d+)

### 🏠 Today / Home

- **Action card more interactive** — hero card CTAs feel static; explore gesture, animation, or contextual action improvements
- **Rebuild momentum card** — ReinforcementSection hidden; redesign as a real weekly score (train days + protein days + sleep days = 3 pillars), not a ring counter
- **Expand quick workouts** — more Quick Recovery variants (yoga flow, foam roll, breathing); surface from Today screen

### 🥗 Food

- **Meal timeline** — show meals logged today as a visual timeline instead of a flat list

### ⚙️ Infrastructure

- **Onboarding flow** — goal, training days, gym type, HealthKit connect
- **Daily momentum score** — 2/3 pillars = success, not streaks
- **Error logging** — structured error log for debugging production issues
- **Security review** — audit AppStorage keys, API key storage, input validation
- **In-app feedback board** — lightweight way for users to report bugs or suggest features
- **Track Anthropic API usage per user** — currently untracked; target €1–2/user/month; add usage monitoring
- **WatchOS companion** — readiness glance, workout log
- **Subscriptions** — €7.99/mo or €59/yr, 7-day trial

### AI Strategy
- `claude-sonnet-4-6`: food photo estimation (current)
- Claude Sonnet (future): weekly summaries, coaching insights
- **Never use AI for:** readiness scoring, progression logic, daily decisions — keep those deterministic
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
