import HealthKit
import SwiftUI
import UIKit

@MainActor
final class HealthKitManager: ObservableObject {

    private let store = HKHealthStore()

    @Published var todayMetrics: DailyMetrics?
    @Published var baselineMetrics: [DailyMetrics] = []
    @Published var currentWeightKg: Double?
    @Published var currentBodyFatPct: Double?
    // Nutrition — summed for today
    @Published var todayKcal: Double?
    @Published var todayProteinG: Double?
    @Published var todayFatG: Double?
    @Published var todayCarbsG: Double?
    // Activity — summed for today
    @Published var todaySteps: Double?
    @Published var todayActiveKcal: Double?
    // Weekly activity (past 7 days keyed by start-of-day Date)
    @Published var weeklySteps: [Date: Double] = [:]
    @Published var weeklyActiveKcal: [Date: Double] = [:]
    /// Most recent running pace from HealthKit (seconds per km). nil = no data or unavailable.
    @Published var recentRunningPaceSecsPerKm: Double? = nil
    /// Today's completed workouts, sorted by startDate ascending.
    @Published var todayWorkouts: [HKWorkout] = []
    @Published var isAuthorized = false
    @Published var isLoading = false
    @Published var authError: String?
    @Published var lastLoadedAt: Date?

    private var foregroundObserver: NSObjectProtocol?

    init() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard self.isAuthorized else { return }
                await self.loadData()
            }
        }
    }

    deinit {
        if let obs = foregroundObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        if let t = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { types.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .restingHeartRate)          { types.insert(t) }
        if let t = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)             { types.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .bodyMass)                  { types.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)         { types.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)     { types.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .dietaryProtein)            { types.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .dietaryFatTotal)           { types.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)      { types.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .stepCount)                 { types.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)        { types.insert(t) }
        // Running speed — for auto-populating pace in IntervalRunSheet (iOS 16+)
        if let t = HKObjectType.quantityType(forIdentifier: .runningSpeed)              { types.insert(t) }
        // Workouts — for displaying today's activity on the Food page timeline
        types.insert(HKObjectType.workoutType())
        return types
    }()

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authError = "HealthKit is not available on this device."
            return
        }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
            await loadData()
        } catch {
            authError = error.localizedDescription
        }
    }

    // MARK: - Data Loading

    func loadData() async {
        guard isAuthorized else { return }
        isLoading = true
        defer { isLoading = false }
        let baselineDays = ReadinessEngine.hrvBaselineDays  // 28 days; engine slices for RHR (7)

        let cal = Calendar.current
        let now = Date()
        let todayStart     = cal.startOfDay(for: now)
        let yesterdayStart = cal.date(byAdding: .day, value: -1, to: todayStart)!

        // Today: HRV and RHR from the overnight window (10pm → 8am), sleep from last night
        let (oStart, oEnd) = overnightWindow(for: todayStart)
        async let hrv   = fetchAverageHRV(from: oStart, to: oEnd)
        async let rhr   = fetchLatestRHR(from: oStart, to: oEnd)
        async let sleep = fetchSleepHours(nightStartingAt: yesterdayStart)

        todayMetrics = DailyMetrics(
            date: todayStart,
            hrv: await hrv,
            rhr: await rhr,
            sleepHours: await sleep
        )

        // Body weight and body fat — most recent sample ever
        currentWeightKg   = await fetchLatestBodyMass()
        currentBodyFatPct = await fetchLatestBodyFatPercentage()

        // Nutrition — sum all samples logged today (iOS 17+ non-failable HKQuantityType init)
        async let kcal    = fetchQuantitySum(type: HKQuantityType(.dietaryEnergyConsumed), unit: .kilocalorie(), from: todayStart, to: now)
        async let protein = fetchQuantitySum(type: HKQuantityType(.dietaryProtein),        unit: .gram(),        from: todayStart, to: now)
        async let fat     = fetchQuantitySum(type: HKQuantityType(.dietaryFatTotal),       unit: .gram(),        from: todayStart, to: now)
        async let carbs   = fetchQuantitySum(type: HKQuantityType(.dietaryCarbohydrates),  unit: .gram(),        from: todayStart, to: now)

        todayKcal     = await kcal
        todayProteinG = await protein
        todayFatG     = await fat
        todayCarbsG   = await carbs

        // Activity — step count and active energy for today
        async let steps      = fetchQuantitySum(type: HKQuantityType(.stepCount),          unit: .count(),       from: todayStart, to: now)
        async let activeKcal = fetchQuantitySum(type: HKQuantityType(.activeEnergyBurned), unit: .kilocalorie(), from: todayStart, to: now)
        todaySteps      = await steps
        todayActiveKcal = await activeKcal

        // Baseline: fetch each of the past N days
        var metrics: [DailyMetrics] = []
        for offset in 1...max(1, baselineDays) {
            let dayStart   = cal.date(byAdding: .day, value: -offset, to: todayStart)!
            let dayEnd     = cal.date(byAdding: .day, value: 1, to: dayStart)!
            let nightStart = cal.date(byAdding: .day, value: -1, to: dayStart)!

            // HRV: overnight window for consistency with today's fetch
            let (bStart, bEnd) = overnightWindow(for: dayStart)
            async let dHRV   = fetchAverageHRV(from: bStart, to: bEnd)
            async let dRHR   = fetchLatestRHR(from: dayStart, to: dayEnd)
            async let dSleep = fetchSleepHours(nightStartingAt: nightStart)

            metrics.append(DailyMetrics(
                date: dayStart,
                hrv: await dHRV,
                rhr: await dRHR,
                sleepHours: await dSleep
            ))
        }
        baselineMetrics = metrics

        // Weekly steps + active kcal for the Insights tab
        await fetchWeeklyActivity()

        // Running pace — most recent sample from the past 30 days
        recentRunningPaceSecsPerKm = await fetchRecentRunningPace()

        // Today's workouts — displayed in the Food page day timeline
        todayWorkouts = await fetchTodayWorkouts()

        lastLoadedAt = Date()
    }

    private func fetchWeeklyActivity() async {
        let cal = Calendar.current
        let now = Date()
        let todayStart = cal.startOfDay(for: now)
        var stepsDict:   [Date: Double] = [:]
        var kcalDict:    [Date: Double] = [:]
        for dayOffset in 0..<7 {
            let dayStart = cal.date(byAdding: .day, value: -dayOffset, to: todayStart)!
            let dayEnd   = cal.date(byAdding: .day, value: 1, to: dayStart)!
            async let s = fetchQuantitySum(type: HKQuantityType(.stepCount),          unit: .count(),       from: dayStart, to: dayEnd)
            async let k = fetchQuantitySum(type: HKQuantityType(.activeEnergyBurned), unit: .kilocalorie(), from: dayStart, to: dayEnd)
            if let v = await s { stepsDict[dayStart] = v }
            if let v = await k { kcalDict[dayStart]  = v }
        }
        weeklySteps      = stepsDict
        weeklyActiveKcal = kcalDict
    }

    // MARK: - Private fetch helpers

    /// Sums a cumulative quantity (steps, calories, nutrition) over a date range.
    /// Uses HKStatisticsQuery so HealthKit deduplicates overlapping sources
    /// (e.g. iPhone + Apple Watch both recording steps) automatically.
    private func fetchQuantitySum(
        type: HKQuantityType,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let value = statistics?.sumQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value.flatMap { $0 > 0 ? $0 : nil })
            }
            self.store.execute(query)
        }
    }

    private func fetchLatestBodyFatPercentage() async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) else { return nil }
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let pct = sample.quantity.doubleValue(for: .percent()) * 100
                continuation.resume(returning: pct)
            }
            store.execute(query)
        }
    }

    private func fetchLatestBodyMass() async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return nil }
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, _ in
                let kg = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: kg)
            }
            store.execute(query)
        }
    }

    /// Returns the overnight window (10pm of previous day → 8am of dayStart) for stable recovery metrics.
    private func overnightWindow(for dayStart: Date) -> (start: Date, end: Date) {
        let cal = Calendar.current
        let prevDay = cal.date(byAdding: .day, value: -1, to: dayStart)!
        var startComps = cal.dateComponents([.year, .month, .day], from: prevDay)
        startComps.hour = 22
        let start = cal.date(from: startComps)!
        var endComps = cal.dateComponents([.year, .month, .day], from: dayStart)
        endComps.hour = 8
        let end = cal.date(from: endComps)!
        return (start, end)
    }

    /// Averages all quantity samples in the window; returns nil when no samples exist.
    private func fetchAverageQuantity(
        type: HKQuantityType,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let values = (samples as? [HKQuantitySample])?.map { $0.quantity.doubleValue(for: unit) } ?? []
                guard !values.isEmpty else { continuation.resume(returning: nil); return }
                continuation.resume(returning: values.reduce(0, +) / Double(values.count))
            }
            self.store.execute(query)
        }
    }

    private func fetchAverageHRV(from start: Date, to end: Date) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return nil }
        return await fetchAverageQuantity(type: type, unit: HKUnit.secondUnit(with: .milli), from: start, to: end)
    }

    private func fetchLatestHRV(from start: Date, to end: Date) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return nil }
        return await fetchLatestQuantity(type: type, unit: HKUnit.secondUnit(with: .milli), from: start, to: end)
    }

    private func fetchLatestRHR(from start: Date, to end: Date) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return nil }
        let bpm = HKUnit.count().unitDivided(by: .minute())
        return await fetchLatestQuantity(type: type, unit: bpm, from: start, to: end)
    }

    private func fetchLatestQuantity(
        type: HKQuantityType,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    /// Fetches the most recent running speed sample (past 30 days) and converts it to sec/km.
    /// HealthKit stores running speed in m/s. Conversion: secsPerKm = 1000 / (m/s).
    /// Returns nil when no samples are available or the device doesn't support the type.
    private func fetchRecentRunningPace() async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: .runningSpeed) else { return nil }
        let from = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: from, end: Date(), options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                // m/s → seconds per km: 1000 / speedMps
                let speedMps = sample.quantity.doubleValue(for: HKUnit.meter().unitDivided(by: .second()))
                guard speedMps > 0 else { continuation.resume(returning: nil); return }
                let secsPerKm = 1000.0 / speedMps
                continuation.resume(returning: secsPerKm)
            }
            self.store.execute(query)
        }
    }

    /// Fetches all completed workouts recorded today (midnight → now), sorted by startDate ascending.
    func fetchTodayWorkouts() async -> [HKWorkout] {
        let cal = Calendar.current
        let now = Date()
        let todayStart = cal.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: todayStart, end: now, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: workouts)
            }
            self.store.execute(query)
        }
    }

    /// Fetches total hours asleep for the night starting at `date` (6 pm → noon next day).
    private func fetchSleepHours(nightStartingAt date: Date) async -> Double? {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }

        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: date)
        comps.hour = 18
        guard let windowStart = cal.date(from: comps) else { return nil }
        let windowEnd = cal.date(byAdding: .hour, value: 18, to: windowStart)!

        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let categorySamples = (samples as? [HKCategorySample]) ?? []
                let asleepSamples = categorySamples.filter { sample in
                    guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { return false }
                    return [.asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM].contains(value)
                }
                let totalSeconds = asleepSamples.reduce(0.0) {
                    $0 + $1.endDate.timeIntervalSince($1.startDate)
                }
                continuation.resume(returning: totalSeconds > 0 ? totalSeconds / 3600 : nil)
            }
            self.store.execute(query)
        }
    }
}
