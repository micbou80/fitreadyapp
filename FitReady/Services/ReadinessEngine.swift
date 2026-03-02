import Foundation

struct AppSettings {
    var baselineDays: Int = 7
    var sleepTargetHours: Double = 7.5
    /// HRV today >= baseline * this → +1 (good)
    var hrvGoodThreshold: Double = 0.95
    /// HRV today >= baseline * this → 0 (neutral)
    var hrvNeutralThreshold: Double = 0.80
    /// RHR today <= baseline * this → +1 (good)
    var rhrGoodThreshold: Double = 1.03
    /// RHR today <= baseline * this → 0 (neutral)
    var rhrNeutralThreshold: Double = 1.08
}

enum ReadinessEngine {

    static func compute(
        today: DailyMetrics,
        baseline: [DailyMetrics],
        settings: AppSettings
    ) -> ReadinessScore {
        let hrvValues = baseline.compactMap(\.hrv)
        let rhrValues = baseline.compactMap(\.rhr)

        let avgHRV = hrvValues.isEmpty ? nil : hrvValues.reduce(0, +) / Double(hrvValues.count)
        let avgRHR = rhrValues.isEmpty ? nil : rhrValues.reduce(0, +) / Double(rhrValues.count)

        let hrvScore   = scoreHRV(today: today.hrv, baseline: avgHRV, settings: settings)
        let rhrScore   = scoreRHR(today: today.rhr, baseline: avgRHR, settings: settings)
        let sleepScore = scoreSleep(today: today.sleepHours, settings: settings)

        let total = hrvScore + rhrScore + sleepScore
        let verdict: ReadinessVerdict
        switch total {
        case 2...:  verdict = .ready
        case 0...1: verdict = .light
        default:    verdict = .rest
        }

        return ReadinessScore(
            verdict: verdict,
            totalScore: total,
            hrvScore: hrvScore,
            rhrScore: rhrScore,
            sleepScore: sleepScore,
            todayHRV: today.hrv,
            todayRHR: today.rhr,
            todaySleep: today.sleepHours,
            baselineHRV: avgHRV,
            baselineRHR: avgRHR
        )
    }

    // MARK: - Private helpers

    private static func scoreHRV(today: Double?, baseline: Double?, settings: AppSettings) -> Int {
        guard let today, let baseline, baseline > 0 else { return 0 }
        if today >= baseline * settings.hrvGoodThreshold    { return  1 }
        if today >= baseline * settings.hrvNeutralThreshold { return  0 }
        return -1
    }

    private static func scoreRHR(today: Double?, baseline: Double?, settings: AppSettings) -> Int {
        guard let today, let baseline, baseline > 0 else { return 0 }
        if today <= baseline * settings.rhrGoodThreshold    { return  1 }
        if today <= baseline * settings.rhrNeutralThreshold { return  0 }
        return -1
    }

    private static func scoreSleep(today: Double?, settings: AppSettings) -> Int {
        guard let today else { return 0 }
        if today >= settings.sleepTargetHours { return  1 }
        if today >= 6.0                       { return  0 }
        return -1
    }
}
