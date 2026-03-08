import SwiftUI
import PhotosUI

// MARK: - Phase

private enum AdvisorPhase {
    case waiting
    case analysing
    case results([MenuDishResult])
    case error(String)
}

// MARK: - Menu Advisor View

/// Embedded camera flow that photos a restaurant menu and returns
/// the top 3 dishes ranked by fit with today's remaining macros.
struct MenuAdvisorView: View {

    let apiKey:      String
    let todayKey:    String
    let onSave:      (MealEntry) -> Void
    let onDismissAll: () -> Void

    @EnvironmentObject private var healthKit: HealthKitManager

    @StateObject private var cam = CameraSession()
    @State private var pickerItem: PhotosPickerItem?
    @State private var menuImage:  UIImage?
    @State private var phase: AdvisorPhase = .waiting

    // Macro target inputs (mirrors FoodView / MacroEngine)
    @AppStorage("heightCm")          private var heightCm:         Double = 0
    @AppStorage("ageYears")          private var ageYears:         Int    = 0
    @AppStorage("biologicalSex")     private var biologicalSex:    String = ""
    @AppStorage("manualWeightKg")    private var manualWeightKg:   Double = 0
    @AppStorage("useManualWeight")   private var useManualWeight:  Bool   = false
    @AppStorage("activityLevel")     private var activityLevel:    String = "moderate"
    @AppStorage("weightLossPace")    private var weightLossPace:   Double = 0
    @AppStorage("proteinPerKg")      private var proteinPerKg:     Double = 1.8
    @AppStorage("fatFloorPct")       private var fatFloorPct:      Double = 25
    @AppStorage("mealsJSON")         private var mealsJSON:        String = "[]"
    @AppStorage("foodPreferences")   private var foodPreferences:  String = ""

    var body: some View {
        content
            .navigationTitle("Menu Advisor")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear   { cam.checkAndStart() }
            .onDisappear { cam.stop() }
            .onChange(of: cam.capturedImage) { _, img in
                guard let img else { return }
                cam.stop()
                menuImage = img
                Task { await analyse() }
            }
            .onChange(of: pickerItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let img  = UIImage(data: data) {
                        menuImage = img
                        await analyse()
                    }
                }
            }
    }

    // MARK: - Phase router

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .waiting:
            waitingPhaseView
        case .analysing:
            ScrollView {
                analysingView.padding(20)
            }
            .background(AppColors.background.ignoresSafeArea())
        case .results(let dishes):
            ScrollView {
                resultsView(dishes: dishes).padding(20)
            }
            .background(AppColors.background.ignoresSafeArea())
        case .error(let msg):
            ScrollView {
                errorView(message: msg).padding(20)
            }
            .background(AppColors.background.ignoresSafeArea())
        }
    }

    // MARK: - Waiting phase

    private var waitingPhaseView: some View {
        VStack(spacing: 0) {

            // Live camera viewfinder
            ZStack {
                Color.black

                if cam.authState == .authorized {
                    LiveCameraView(session: cam.session)
                } else if cam.authState == .denied {
                    permissionDeniedOverlay
                }

                CornerBrackets()

                VStack {
                    Spacer()
                    Button { cam.capturePhoto() } label: {
                        ZStack {
                            Circle().stroke(.white.opacity(0.45), lineWidth: 3).frame(width: 72, height: 72)
                            Circle().fill(.white).frame(width: 60, height: 60)
                        }
                    }
                    .disabled(cam.authState != .authorized)
                    .padding(.bottom, 28)
                }
            }
            .frame(height: 380)

            // Remaining macros summary + library option
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // Remaining macros summary
                    if let rem = remainingMacros {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Text("TODAY'S REMAINING")
                                .font(DS.Typography.label())
                                .foregroundStyle(AppColors.textSecondary)
                                .kerning(0.5)

                            HStack(spacing: DS.Spacing.sm) {
                                macroPill(value: rem.kcal,    unit: "kcal", color: AppColors.dataCalories)
                                macroPill(value: rem.protein, unit: "P",    color: AppColors.dataProtein)
                                macroPill(value: rem.fat,     unit: "F",    color: AppColors.dataFat)
                                macroPill(value: rem.carbs,   unit: "C",    color: AppColors.dataCarbs)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 12)

                        Divider()
                    }

                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        HStack(spacing: 14) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 18))
                                .foregroundStyle(AppColors.accent)
                                .frame(width: 32)
                            Text("Choose from Photo Library")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(AppColors.accent)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppColors.textMuted)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }

                    if !foodPreferences.isEmpty {
                        Divider()
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.greenText)
                            Text("Filtering for: \(preferencesLabel)")
                                .font(.system(size: 12))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func macroPill(value: Int, unit: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text("\(value)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
            Text(unit)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color.opacity(0.8))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    private var permissionDeniedOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.slash.fill")
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.6))
            Text("Camera access needed")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.accent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Analysing phase

    private var analysingView: some View {
        VStack(spacing: 20) {
            if let img = menuImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: AppColors.shadowColor, radius: 8, x: 0, y: 2)
            }
            VStack(spacing: 12) {
                ProgressView().scaleEffect(1.3)
                Text("Reading menu…")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                Text("This may take a few seconds")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: AppColors.shadowColor, radius: 8, x: 0, y: 2)
        }
    }

    // MARK: - Results phase

    private func resultsView(dishes: [MenuDishResult]) -> some View {
        VStack(spacing: 20) {

            // Menu thumbnail
            if let img = menuImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 130)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: AppColors.shadowColor, radius: 8, x: 0, y: 2)
            }

            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("TOP PICKS FOR YOU")
                    .font(DS.Typography.label())
                    .foregroundStyle(AppColors.textMuted)
                    .kerning(0.4)
                if let rem = remainingMacros {
                    Text("Based on \(rem.kcal) kcal · \(rem.protein)g protein remaining")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Dish cards
            ForEach(dishes, id: \.rank) { dish in
                dishCard(dish)
            }

            // Start over
            Button {
                menuImage = nil
                pickerItem = nil
                phase = .waiting
                cam.restart()
            } label: {
                Text("Scan a different menu")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func dishCard(_ dish: MenuDishResult) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {

            // Rank + name
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                Text("#\(dish.rank)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(rankTextColor(dish.rank))
                    .frame(width: 30, height: 22)
                    .background(rankColor(dish.rank))
                    .clipShape(Capsule())

                Text(dish.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()
            }

            // Macro pills
            HStack(spacing: DS.Spacing.sm) {
                macroPill(value: Int(dish.kcal.rounded()),    unit: "kcal", color: AppColors.dataCalories)
                macroPill(value: Int(dish.proteinG.rounded()), unit: "P",   color: AppColors.dataProtein)
                macroPill(value: Int(dish.fatG.rounded()),    unit: "F",    color: AppColors.dataFat)
                macroPill(value: Int(dish.carbsG.rounded()),  unit: "C",    color: AppColors.dataCarbs)
            }

            // Reason
            if !dish.reason.isEmpty {
                Text(dish.reason)
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.textSecondary)
            }

            // Log button
            Button {
                let entry = MealEntry(
                    date:     todayKey,
                    name:     dish.name,
                    kcal:     dish.kcal,
                    proteinG: dish.proteinG,
                    fatG:     dish.fatG,
                    carbsG:   dish.carbsG,
                    source:   "scan"
                )
                onSave(entry)
                onDismissAll()
            } label: {
                Label("Log this meal", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(rankTextColor(dish.rank))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(rankColor(dish.rank))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Corner.button))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
        .shadow(color: DS.Shadow.color, radius: DS.Shadow.radius, x: 0, y: DS.Shadow.y)
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1:  return AppColors.brandPrimary
        case 2:  return AppColors.warning
        default: return AppColors.surface
        }
    }

    private func rankTextColor(_ rank: Int) -> Color {
        rank <= 2 ? AppColors.textOnBrand : AppColors.textSecondary
    }

    // MARK: - Error phase

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(AppColors.amberBase)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            Button {
                menuImage = nil
                phase = .waiting
                cam.restart()
            } label: {
                Label("Try Again", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.accent)
        }
        .padding(24)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppColors.shadowColor, radius: 8, x: 0, y: 2)
    }

    // MARK: - Analysis

    private func analyse() async {
        guard let image = menuImage else { return }
        phase = .analysing

        let rem = remainingMacros ?? (kcal: 2000, protein: 150, fat: 65, carbs: 200)
        let apiKeyToUse = apiKey.isEmpty ? (UserDefaults.standard.string(forKey: "anthropicAPIKey") ?? "") : apiKey

        do {
            let dishes = try await AnthropicService.analyseMenu(
                image:            image,
                remainingKcal:    rem.kcal,
                remainingProtein: rem.protein,
                remainingFat:     rem.fat,
                remainingCarbs:   rem.carbs,
                preferences:      foodPreferences,
                apiKey:           apiKeyToUse
            )
            phase = dishes.isEmpty ? .error("No dishes found on the menu. Try a clearer photo.") : .results(dishes)
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    // MARK: - Remaining macros

    private var remainingMacros: (kcal: Int, protein: Int, fat: Int, carbs: Int)? {
        guard let targets = macroTargets else { return nil }

        let consumed: (kcal: Double, protein: Double, fat: Double, carbs: Double)

        if let hkKcal = healthKit.todayKcal {
            consumed = (
                kcal:    hkKcal,
                protein: healthKit.todayProteinG ?? 0,
                fat:     healthKit.todayFatG     ?? 0,
                carbs:   healthKit.todayCarbsG   ?? 0
            )
        } else {
            consumed = mealTotals()
        }

        return (
            kcal:    max(0, targets.kcal     - Int(consumed.kcal.rounded())),
            protein: max(0, targets.proteinG - Int(consumed.protein.rounded())),
            fat:     max(0, targets.fatG     - Int(consumed.fat.rounded())),
            carbs:   max(0, targets.carbsG   - Int(consumed.carbs.rounded()))
        )
    }

    private var macroTargets: MacroTargets? {
        let weight: Double
        if useManualWeight && manualWeightKg > 0 {
            weight = manualWeightKg
        } else if let hkW = healthKit.currentWeightKg, hkW > 0 {
            weight = hkW
        } else {
            return nil
        }
        guard heightCm > 0, ageYears > 0 else { return nil }
        return MacroEngine.compute(
            weightKg:      weight,
            heightCm:      heightCm,
            ageYears:      ageYears,
            isMale:        biologicalSex == "male",
            activityLevel: activityLevel,
            paceKgPerWeek: weightLossPace,
            proteinPerKg:  proteinPerKg,
            fatFloorPct:   fatFloorPct
        )
    }

    private func mealTotals() -> (kcal: Double, protein: Double, fat: Double, carbs: Double) {
        guard let entries = try? JSONDecoder().decode([MealEntry].self, from: Data(mealsJSON.utf8)) else {
            return (0, 0, 0, 0)
        }
        let today = entries.filter { $0.date == todayKey }
        return (
            kcal:    today.reduce(0) { $0 + $1.kcal },
            protein: today.reduce(0) { $0 + $1.proteinG },
            fat:     today.reduce(0) { $0 + $1.fatG },
            carbs:   today.reduce(0) { $0 + $1.carbsG }
        )
    }

    private var preferencesLabel: String {
        foodPreferences
            .split(separator: ",")
            .map { $0.replacingOccurrences(of: "-", with: " ").capitalized }
            .joined(separator: ", ")
    }
}
