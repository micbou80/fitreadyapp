import SwiftUI
import PhotosUI

/// The V2 Today screen: decision-first, low-friction daily guidance.
///
/// Layout (top → bottom):
///   1. WeekCalendarStrip     — current week with today's readiness badge
///   2. TodayHeroSection      — state + headline + reassurance + reason + "See details"
///   3. PrimaryActionSection  — single recommended workout CTA
///   4. SecondaryActionsSection — Log meal + mobility/steps
///   5. ReinforcementSection  — momentum ring + win
///   6. CollapsedStatusSection — steps / active kcal / protein chips (expandable)
///
/// Uses mock data on init; wires to live HealthKit data via `updateFromHealthKit()`.
struct TodayView: View {

    @EnvironmentObject private var healthKit: HealthKitManager
    @StateObject private var vm = TodayViewModel(mockState: .yellow)

    // Profile picture
    @AppStorage("profilePhotoData")         private var profilePhotoData: Data   = Data()
    @State private var showingProfilePicker = false
    @State private var selectedProfilePhoto: PhotosPickerItem?

    // Settings needed to compute ReadinessScore + MacroTargets
    @AppStorage("baselineDays")          private var baselineDays: Int    = 7
    @AppStorage("sleepTargetHours")      private var sleepTargetHours: Double = 7.5
    @AppStorage("hrvGoodThreshold")      private var hrvGoodThreshold: Double = 0.95
    @AppStorage("hrvNeutralThreshold")   private var hrvNeutralThreshold: Double = 0.80
    @AppStorage("rhrGoodThreshold")      private var rhrGoodThreshold: Double = 1.03
    @AppStorage("rhrNeutralThreshold")   private var rhrNeutralThreshold: Double = 1.08
    @AppStorage("heightCm")             private var heightCm: Double = 0
    @AppStorage("ageYears")             private var ageYears: Int    = 0
    @AppStorage("biologicalSex")        private var biologicalSex: String = ""
    @AppStorage("activityLevel")        private var activityLevel: String = "moderate"
    @AppStorage("weightLossPace")       private var weightLossPace: Double = 0.5
    @AppStorage("proteinPerKg")         private var proteinPerKg: Double = 1.8
    @AppStorage("fatFloorPct")          private var fatFloorPct: Double = 25
    @AppStorage("manualWeightKg")       private var manualWeight: Double = 0
    @AppStorage("useManualWeight")      private var useManualWeight: Bool = false

    // MARK: - Derived

    private var displayWeight: Double? {
        if useManualWeight { return manualWeight > 0 ? manualWeight : nil }
        return healthKit.currentWeightKg
    }

    private var macroTargets: MacroTargets? {
        guard let wt = displayWeight, heightCm > 0, ageYears > 0, !biologicalSex.isEmpty else { return nil }
        return MacroEngine.compute(
            weightKg:      wt,
            heightCm:      heightCm,
            ageYears:      ageYears,
            isMale:        biologicalSex == "male",
            activityLevel: activityLevel,
            paceKgPerWeek: weightLossPace,
            proteinPerKg:  proteinPerKg,
            fatFloorPct:   fatFloorPct
        )
    }

    private var readinessScore: ReadinessScore? {
        guard let today = healthKit.todayMetrics,
              !healthKit.baselineMetrics.isEmpty else { return nil }
        let settings = AppSettings(
            baselineDays:        baselineDays,
            sleepTargetHours:    sleepTargetHours,
            hrvGoodThreshold:    hrvGoodThreshold,
            hrvNeutralThreshold: hrvNeutralThreshold,
            rhrGoodThreshold:    rhrGoodThreshold,
            rhrNeutralThreshold: rhrNeutralThreshold
        )
        return ReadinessEngine.compute(today: today, baseline: healthKit.baselineMetrics, settings: settings)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DS.Spacing.xl) {
                        WeekCalendarStrip(vm: vm)
                        TodayHeroSection(vm: vm)
                        PrimaryActionSection(vm: vm)
                        SecondaryActionsSection(vm: vm)
                        ReinforcementSection(vm: vm)
                        CollapsedStatusSection(vm: vm)
                        Spacer(minLength: DS.Spacing.xl)
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.sm)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    profileAvatarButton
                }
            }
            .sheet(isPresented: $vm.detailsSheetVisible) {
                ReadinessDetailsSheet(vm: vm)
            }
            .photosPicker(
                isPresented: $showingProfilePicker,
                selection: $selectedProfilePhoto,
                matching: .images
            )
        }
        .onAppear            { updateFromHealthKit() }
        // Observe all HealthKit signals — including baselineMetrics which was missing before
        .onChange(of: healthKit.todayMetrics)     { _, _ in updateFromHealthKit() }
        .onChange(of: healthKit.baselineMetrics)  { _, _ in updateFromHealthKit() }
        .onChange(of: healthKit.todayKcal)        { _, _ in updateFromHealthKit() }
        .onChange(of: healthKit.todaySteps)       { _, _ in updateFromHealthKit() }
        .onChange(of: healthKit.todayActiveKcal)  { _, _ in updateFromHealthKit() }
        // Resize and save selected profile photo
        .onChange(of: selectedProfilePhoto) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self),
                      let src  = UIImage(data: data) else { return }
                let size  = CGSize(width: 200, height: 200)
                let small = UIGraphicsImageRenderer(size: size).image { _ in
                    src.draw(in: CGRect(origin: .zero, size: size))
                }
                if let jpeg = small.jpegData(compressionQuality: 0.75) {
                    profilePhotoData = jpeg
                }
            }
        }
    }

    // MARK: - Profile avatar

    private var profileAvatarButton: some View {
        Button { showingProfilePicker = true } label: {
            profileAvatar
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var profileAvatar: some View {
        if !profilePhotoData.isEmpty, let img = UIImage(data: profilePhotoData) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: 34, height: 34)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .foregroundStyle(Color(.secondaryLabel))
                .frame(width: 34, height: 34)
        }
    }

    // MARK: - HealthKit sync

    private func updateFromHealthKit() {
        guard let score = readinessScore else { return }
        vm.update(from: score, healthKit: healthKit, macroTargets: macroTargets)
    }
}

// MARK: - Previews

#Preview("Yellow state") {
    TodayView()
        .environmentObject(HealthKitManager())
}

#Preview("Green state") {
    let vm = TodayViewModel(mockState: .green)
    return NavigationStack {
        ZStack {
            DS.Background.page.ignoresSafeArea()
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    WeekCalendarStrip(vm: vm)
                    TodayHeroSection(vm: vm)
                    PrimaryActionSection(vm: vm)
                    SecondaryActionsSection(vm: vm)
                    ReinforcementSection(vm: vm)
                    CollapsedStatusSection(vm: vm)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.sm)
            }
        }
    }
}

#Preview("Red state") {
    let vm = TodayViewModel(mockState: .red)
    return NavigationStack {
        ZStack {
            DS.Background.page.ignoresSafeArea()
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    WeekCalendarStrip(vm: vm)
                    TodayHeroSection(vm: vm)
                    PrimaryActionSection(vm: vm)
                    SecondaryActionsSection(vm: vm)
                    ReinforcementSection(vm: vm)
                    CollapsedStatusSection(vm: vm)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.sm)
            }
        }
    }
}
