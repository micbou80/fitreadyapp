import Foundation

struct DailyMetrics: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let hrv: Double?        // ms (SDNN)
    let rhr: Double?        // bpm
    let sleepHours: Double? // hours
}
