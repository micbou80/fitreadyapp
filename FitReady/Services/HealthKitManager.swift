import HealthKit
import SwiftUI

@MainActor
final class HealthKitManager: ObservableObject {

    private let store = HKHealthStore()

    @Published var todayMetrics: DailyMetrics?
    @Published var baselineMetrics: [DailyMetrics] = []
    @Published var currentWeightKg: Double?
    @Published var currentBodyFatPct: Double?
    @Published var isAuthorized = false
    @Published var isLoading = false
    @Published var authError: String?

    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        if let t = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { types.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .restingHeartRate)          { types.insert(t) }
        if let t = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)             { types.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .bodyMass)                  { types.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)         { types.insert(t) }
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

    func loadData(baselineDays: Int = 7) async {
        guard isAuthorized else { return }
        isLoading = true
        defer { isLoading = false }

        let cal = Calendar.current
        let now = Date()
        let todayStart    = cal.startOfDay(for: now)
        let yesterdayStart = cal.date(byAdding: .day, value: -1, to: todayStart)!

        // Today: fetch HRV and RHR from the last 24 h, sleep from last night
        async let hrv   = fetchLatestHRV(from: yesterdayStart, to: now)
        async let rhr   = fetchLatestRHR(from: yesterdayStart, to: now)
        async let sleep = fetchSleepHours(nightStartingAt: yesterdayStart)

        todayMetrics = DailyMetrics(
            date: todayStart,
            hrv: await hrv,
            rhr: await rhr,
            sleepHours: await sleep
        )

        // Body weight and body fat — most recent sample ever
        currentWeightKg    = await fetchLatestBodyMass()
        currentBodyFatPct  = await fetchLatestBodyFatPercentage()

        // Baseline: fetch each of the past N days
        var metrics: [DailyMetrics] = []
        for offset in 1...max(1, baselineDays) {
            let dayStart  = cal.date(byAdding: .day, value: -offset, to: todayStart)!
            let dayEnd    = cal.date(byAdding: .day, value: 1, to: dayStart)!
            let nightStart = cal.date(byAdding: .day, value: -1, to: dayStart)!

            async let dHRV   = fetchLatestHRV(from: dayStart, to: dayEnd)
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
    }

    // MARK: - Private fetch helpers

    private func fetchLatestBodyFatPercentage() async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) else { return nil }
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, _ in
                // HealthKit stores body fat as a fraction (0.18 = 18%); convert to display percentage
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
