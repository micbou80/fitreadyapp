import Foundation

struct MealEntry: Codable, Identifiable {
    var id: UUID
    let date: String        // "YYYY-MM-DD"
    let timestamp: Date
    let name: String        // AI description or "Manual entry"
    let kcal: Double
    let proteinG: Double
    let fatG: Double
    let carbsG: Double
    let source: String      // "scan" | "manual"

    init(date: String, timestamp: Date = Date(), name: String,
         kcal: Double, proteinG: Double, fatG: Double, carbsG: Double,
         source: String) {
        self.id        = UUID()
        self.date      = date
        self.timestamp = timestamp
        self.name      = name
        self.kcal      = kcal
        self.proteinG  = proteinG
        self.fatG      = fatG
        self.carbsG    = carbsG
        self.source    = source
    }
}
