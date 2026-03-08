import SwiftUI

/// Up to 2 secondary action cards.
/// - `.scanMeal`      → opens FoodScannerSheet
/// - `.quickRecovery` → opens RecoveryWorkoutView (full-screen, locked flow)
struct SecondaryActionsSection: View {

    @ObservedObject var vm: TodayViewModel

    @AppStorage("anthropicAPIKey") private var apiKey:    String = ""
    @AppStorage("mealsJSON")       private var mealsJSON: String = "[]"
    @State private var showingScanner  = false
    @State private var showingRecovery = false

    private var todayKey: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            ForEach(vm.secondaryActions) { action in
                secondaryCard(action)
            }
        }
        .sheet(isPresented: $showingScanner) {
            FoodScannerSheet(apiKey: apiKey, todayKey: todayKey) { entry in
                saveMealEntry(entry)
            }
        }
        .fullScreenCover(isPresented: $showingRecovery) {
            RecoveryWorkoutView()
        }
    }

    @ViewBuilder
    private func secondaryCard(_ action: SecondaryAction) -> some View {
        Button {
            switch action.kind {
            case .scanMeal:
                showingScanner = true
            case .quickRecovery:
                showingRecovery = true
            case .general:
                break
            }
            Haptics.impact(.light)
        } label: {
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: action.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(width: 46, height: 46)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(action.label)
                    .font(DS.Typography.caption())
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(DS.Spacing.md)
            .background(DS.Background.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
            .shadow(color: DS.Shadow.color, radius: DS.Shadow.radius, x: 0, y: DS.Shadow.y)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Meal persistence

    private func saveMealEntry(_ entry: MealEntry) {
        var meals = (try? JSONDecoder().decode([MealEntry].self, from: Data(mealsJSON.utf8))) ?? []
        meals.append(entry)
        if let data = try? JSONEncoder().encode(meals),
           let json = String(data: data, encoding: .utf8) {
            mealsJSON = json
        }
    }
}
