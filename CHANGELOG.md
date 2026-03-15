# CHANGELOG

---

## 2026-03-15 — Fix food timeline icons invisible on light theme

### Fixed

- **Timeline rail icons invisible in light mode** — Both the meal (`fork.knife`) and workout activity icons in the Food page day timeline used `AppColors.brandMuted` as the circle background, which is a dark colour that does not adapt to light mode. Dark icons on a dark background made them invisible. Updated both cases in `timelineRailIcon` to use `AppColors.accentGold.opacity(0.18)` as the circle fill and `AppColors.textPrimary` as the icon foreground — the same adaptive pattern used by Profile page menu rows. Works correctly in both light and dark themes.

---

## 2026-03-14 — WorkoutSummarySheet uses real body weight for kcal estimate

### Changed

- **Accurate kcal estimate in WorkoutSummarySheet** — The "Est. energy burned" range now uses `HealthKitManager.currentWeightKg` (the most recent body-mass sample from Apple Health) instead of a hardcoded 75 kg placeholder. Falls back to 75 kg when no weight is recorded in Health. The calorie-note footer dynamically explains which source was used, so users always understand the accuracy level of the displayed figure.

---

## 2026-03-14 — Fix energy burned discrepancy between Today and Insights pages

### Fixed

- **Energy burned mismatch** — The Today page (Energy Balance card) showed a different "kcal burned" value than the Insights page (Energy Balance section). Root cause: Today used `macroTargets.tdee` (BMR × activity multiplier — a static estimate, e.g. 2444 kcal), while Insights computed `bmr + healthKit.todayActiveKcal` (BMR + live Apple Watch active kcal — a real-time partial sum, e.g. 2303 kcal). Fixed by making Insights use `Double(targets.tdee)` — the same MacroEngine TDEE used by the Today page — as the "Total burn (TDEE)" figure. The BMR and NEAT rows remain visible for informational context; only the bolded "Total burn" line is now aligned with the Today page.

---

## 2026-03-14 — Profile page status icon fix + hero card status chip

### Fixed

- **Status row icon inconsistency** — Icon in the Status section row now uses `.weight(.medium)` (was `.regular`), `UserStatus.color` as foreground (was hardcoded `brandPrimary`), and `UserStatus.color.opacity(0.18)` as background (was `AppColors.raised`). Now matches the `rowContent` icon pattern used everywhere else on the page.

### Added

- **Status chip in hero card** — A small capsule chip (icon + label, `UserStatus.color.opacity(0.28)` background, `heroText` foreground) appears between the goal tagline and goal progress bar when `userStatus` is non-active (Sick / Injured / On a break). Invisible in the normal Active state so it adds no visual noise day-to-day.

---

## 2026-03-14 — Workouts on Food page day timeline

### Added

- **Workout entries in Food page timeline** — Today's completed HealthKit workouts (`HKWorkout`) are now fetched and interleaved with meal entries in a unified chronological timeline. Workout rows display a `brandMuted`-coloured circle with an activity-specific SF Symbol (run, walk, cycle, strength, etc.), the workout type name, and a subtitle showing duration in minutes and kcal burned (when available). `HealthKitManager` now requests `HKObjectType.workoutType()` read permission and publishes `todayWorkouts: [HKWorkout]` — fetched on every `loadAll()` call.

### Notes

- `TimelineEntry` enum (`case meal(MealEntry)`, `case workout(HKWorkout)`) is private to `FoodView.swift` and drives the merged sort. No changes to meal delete or macro chips.
- Workout permission is added to the existing `readTypes` set; no new authorization prompt is triggered if the user already granted HealthKit access (iOS will lazily surface the new type on first launch).

---

## 2026-03-14 — Set Status sheet redesign + Insights weekly hero card

### Changed

- **Set Status sheet redesign** — Replaced the inline chip-grid picker in `ProfileView` with a tappable summary row that opens a full modal sheet (`SetStatusSheet`). The sheet follows the design reference exactly: bold "Set Status" title, four full-width rows (icon · name + subtitle · radio button), and a full-width "DONE" button at the bottom. Selected row background uses `AppColors.raised` (DeepMoss — always dark); radio uses `AppColors.brandPrimary` filled circle; unselected row uses `AppColors.surface` with an `AppColors.border` ring. Rows are separated by `DS.Spacing.sm` gaps, corner `DS.Corner.card`, outer padding `DS.Spacing.lg`, min row height 70pt.
- **`UserStatus` copy + icons updated** — Taglines and SF Symbol icon names updated to match design spec: `figure.run`, `sun.horizon`, `thermometer`, `figure.mind.and.body`. Taglines changed to: "Being healthy and active.", "Taking a few days off to recover.", "Needing rest to get well.", "Needing time to heal."

### Added

- **Weekly progress hero card (`WeeklyProgressHeroCard`)** — New `SoftCard`-based hero card inserted at the top of the Insights tab (above Goal Progress). Shows: "THIS WEEK" label (uppercased, `DS.Typography.label()`, `AppColors.textSecondary`); three stat blocks side by side — Workouts (`WorkoutStore` count vs. planned from `weeklyPlan`), Active kcal (sum of `healthKit.weeklyActiveKcal`), Steps (sum of `healthKit.weeklySteps`); a Mon–Sun 7-dot strip where workout days show filled `brandPrimary` dots, today shows a `brandPrimary` dot with a subtle ring, and rest/future days show empty `metricInactive` ring dots. Stat numbers use `DS.Typography.hero()` weight.

### Notes

- One bright element rule maintained: in the Set Status sheet the only `brandPrimary` fill is the selected radio button; the Done button uses `AppColors.raised` (DeepMoss). On the Insights tab, `brandPrimary` is used only for today's dot and filled workout-day dots — no second lime CTA exists on the same visible screen region as the sheet.
- `WeeklyProgressHeroCard` is declared `struct` (not `private struct`) so it can be previewed independently if needed in future.

---

## 2026-03-14 — Workout fixes, user status, weekly review, meal timeline, error log

### Fixed

- **Timer on run workout (IntervalRunSheet)** — The old implementation used a plain counter incremented on every timer tick. When the app was backgrounded (screen lock, multitasking) the Timer stopped but elapsed time kept being shown as if the app was still visible, causing drift of minutes. Replaced with a wall-clock anchor approach: `startDate` and `phaseStartDate` are stored as `Date` values and elapsed/remaining are derived from `Date().timeIntervalSince(...)` on every tick and on `willEnterForegroundNotification`. Pause/resume also re-anchors the wall clock so paused time is never counted. This matches the approach already used in `ActiveWorkoutSheet`.

### Added

- **Adjust number of sets during a workout** — Added `+` / `−` controls at the bottom of each `ExerciseCard` in `ActiveWorkoutSheet`. The `−` button removes the last set (disabled at 1 set minimum). The `+` button appends a new set pre-filled with the previous set's weight and reps. Both animate with `.spring`. Callbacks are passed from `ActiveWorkoutSheet` to `ExerciseCard`.

- **Auto-load pace on run workout** — HealthKit's `HKQuantityTypeIdentifier.runningSpeed` (iOS 16+, m/s) is now requested at auth and queried in `HealthKitManager.loadData()`. The most recent sample from the past 30 days is converted to seconds/km and published as `recentRunningPaceSecsPerKm`. `IntervalRunSheet` reads this on `.onAppear` to pre-populate all pace fields. If no HealthKit data is available the fields remain blank as before.

  **HealthKit findings:** `runningSpeed` is available on iOS 16+ without any additional entitlement. It is written by the built-in Workout app and third-party running apps. The value is the instantaneous speed during a run, not an average pace — so the most recent sample gives the user's last known running speed. This is a reasonable default; users can always edit the field. Background delivery is NOT used (personal team entitlement constraint). The new type is added to `readTypes` in `HealthKitManager`.

- **End-of-workout card (`WorkoutSummarySheet`)** — A new sheet shown automatically after saving a workout (both `ActiveWorkoutSheet` and `IntervalRunSheet`). Displays: duration formatted as `m min`, total completed sets, estimated kcal burned as a range (MET × 75 kg baseline × hours), and progression highlights (exercises where the user lifted heavier than the template default). A disclaimer notes the 75 kg baseline and suggests logging to Apple Fitness for a personalised figure. The card is presented via `sheet(item:)` binding on a `WorkoutSession?` state variable so it's always populated with the correct session data.

- **User status setting** — New `UserStatus` enum in `TodayModels.swift` with four values: `active`, `sick`, `injured`, `on_break`. Stored in `@AppStorage("userStatus")`. UI lives in `ProfileView` as a new "Status" section with a 2-column chip grid. When non-active:
  - Readiness verdict is overridden: sick/on-break → Rest, injured → Go Light
  - `TodayHeroSection` shows a coloured status banner above the readiness chip
  - Hero headline and reassurance copy adapt to the status (calm, non-punishing copy)
  - CTA actions adapt: sick → breathe, injured → mobility, on-break → breathe

- **Expand the action card** — CTAs in `TodayHeroSection` are now contextually generated based on: user status override, readiness state, time of day (morning/afternoon/evening), and today's plan type. Evening (≥ 18:00) promotes food logging. Rest state routes to breathing (evening) or easy walk (morning/afternoon). Status overrides (sick/injured/break) route to appropriate gentle activities.

- **Weekly review card (`WeeklyReviewCard`)** — New card added at the bottom of the Today screen. Shows: Mon–Sun day strip (active dots for days with ≥ 7,500 steps), workouts logged this week vs. planned training days, total weekly steps, and total active kcal. Data pulled from `WorkoutStore` (workouts) and `healthKit.weeklySteps` / `healthKit.weeklyActiveKcal` (activity). Built with `SoftCard`.

- **Daily meal timeline** — Replaced the flat `ForEach` list in `FoodView`'s meal log card with a visual timeline. Meals are sorted by timestamp. Each entry shows: time (monospaced), source icon (camera/pencil), meal name, and individual macro chips (kcal / P / C / F). A coloured dot on the timeline rail indicates the source (lime = scanned, secondary = manual). The card header now uses `DS.Typography` tokens and `.ultraThinMaterial` + border + shadow (previously used `AppColors.shadowColor` without the border overlay — brought into line with design system).

- **Error log (`AppLogger` + `ErrorLogView`)** — `AppLogger.shared.log(...)` is a lightweight structured logger backed by UserDefaults JSON (capped at 200 entries, newest-first). Each entry has: UUID, timestamp, level (info/warning/error), tag string, message, optional details. `ErrorLogView` is accessible from Settings → Developer section, shows entries with a level filter chip row and tap-to-expand for details. A clear-all button with confirmation dialog is included.

- **Feedback board** — Added a "Feedback" section to `SettingsView` with a `Link` to `https://fitready.canny.io`. Uses simple URL link as instructed (no custom solution). Canny was chosen as the platform: free tier supports public boards, iOS-friendly workflow, used widely in indie apps.

### Changed

- `HealthKitManager` — Added `recentRunningPaceSecsPerKm: Double?` published property and `fetchRecentRunningPace()` private method. Added `runningSpeed` to `readTypes`.
- `TodayModels.swift` — Added `UserStatus` enum before `PlanDayType`.
- `TodayViewModel` — `update()` now accepts `userStatus: UserStatus` parameter and applies its readiness override. Added `currentUserStatus: UserStatus` published property.
- `TodayView` — Reads `@AppStorage("userStatus")` and passes it to `vm.update()`. Adds `.onChange(of: userStatus)` observer.
- `TodayHeroSection` — Status banner, contextual CTAs, status-aware copy.
- `ProfileView` — New `statusSection` between Account and Preferences. Added `userStatus` AppStorage.
- `ActiveWorkoutSheet` — `saveAndFinish()` now sets `completedSession` instead of calling `dismiss()` directly (dismiss happens when the summary sheet closes). Added `onAddSet`/`onRemoveSet` closures to `ExerciseCard`.
- `IntervalRunSheet` — Wall-clock timer logic, HealthKit pace auto-load, summary sheet wiring.
- `FoodView` — Meal log replaced with timeline; card styling brought into design system.
- `SettingsView` — Added Feedback section and Developer / Error log link.

### Notes

- **Running pace HealthKit approach:** `runningSpeed` samples are written by the built-in Workout app and any third-party running app that writes to HealthKit. They represent instantaneous speed, not average session pace. For users who don't use HealthKit-connected running apps the field will remain blank. A future improvement could fall back to the user's last saved pace from WorkoutStore.
- **Estimated kcal in WorkoutSummarySheet:** Uses a fixed 75 kg placeholder since body weight isn't plumbed into the workout flow. A future iteration should read from `HealthKitManager.currentWeightKg` or the profile. The range band (low/high MET) is intentionally imprecise to avoid false precision.
- **Canny feedback platform:** No account creation was done — the URL `fitready.canny.io` is a placeholder assuming the owner would set up a Canny board. If a different platform is preferred (Productboard, Linear, etc.) only the URL needs changing.
- **AppLogger not yet called anywhere in the app:** The service is live and tested via the ErrorLogView preview. Call sites can be added incrementally — particularly in `AnthropicService`, `WorkoutStore`, and `HealthKitManager` error paths.
- **UUID counters updated:** Next available build file UUID: `BF00000000000000000000CF`. Next available file reference UUID: `BF00000000000000000000D0`.

### AppStorage keys added

| Key | Type | Default | Purpose |
|-----|------|---------|---------|
| `userStatus` | String | `"active"` | User's current health/training status (active/sick/injured/on_break) |
