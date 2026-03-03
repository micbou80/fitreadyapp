import Foundation

// MARK: - MacroTargets

struct MacroTargets {
    let kcal: Int
    let proteinG: Int
    let fatG: Int
    let carbsG: Int
}

// MARK: - MacroEngine

enum MacroEngine {

    /// Returns nil if any required input is missing / invalid.
    static func compute(
        weightKg: Double,
        heightCm: Double,
        ageYears: Int,
        isMale: Bool,
        activityLevel: String,
        paceKgPerWeek: Double,   // 0 = maintenance
        proteinPerKg: Double,    // g per kg body weight
        fatFloorPct: Double      // min fat as % of total calories
    ) -> MacroTargets? {
        guard weightKg > 0, heightCm > 0, ageYears > 0 else { return nil }

        // ── BMR (Mifflin-St Jeor) ───────────────────────
        let sexOffset = isMale ? 5.0 : -161.0
        let bmr = 10 * weightKg + 6.25 * heightCm - 5.0 * Double(ageYears) + sexOffset

        // ── TDEE ────────────────────────────────────────
        let tdee = bmr * multiplier(for: activityLevel)

        // ── Calorie target ───────────────────────────────
        // 7 700 kcal ≈ 1 kg body fat
        let deficitPerDay = paceKgPerWeek * 7700.0 / 7.0
        let calTarget = max(tdee - deficitPerDay, 1200)   // absolute floor

        // ── Protein ──────────────────────────────────────
        let proteinG    = max(1, Int(round(weightKg * proteinPerKg)))
        let proteinKcal = Double(proteinG) * 4.0

        // ── Fat ──────────────────────────────────────────
        let fatKcal = calTarget * (fatFloorPct / 100.0)
        let fatG    = max(1, Int(round(fatKcal / 9.0)))

        // ── Carbs ─────────────────────────────────────────
        let carbsKcal = max(0, calTarget - proteinKcal - fatKcal)
        let carbsG    = max(0, Int(round(carbsKcal / 4.0)))

        return MacroTargets(
            kcal:     Int(round(calTarget)),
            proteinG: proteinG,
            fatG:     fatG,
            carbsG:   carbsG
        )
    }

    static func multiplier(for level: String) -> Double {
        switch level {
        case "sedentary": return 1.20
        case "light":     return 1.375
        case "active":    return 1.725
        default:          return 1.55   // "moderate"
        }
    }

    static func levelLabel(for key: String) -> String {
        switch key {
        case "sedentary": return "Sedentary"
        case "light":     return "Lightly Active"
        case "active":    return "Very Active"
        default:          return "Moderately Active"
        }
    }
}
