import SwiftUI
import PhotosUI

/// Profile hub: circular photo + name + stats row, then nav rows into sub-views.
struct ProfileView: View {

    @EnvironmentObject private var healthKit: HealthKitManager

    @AppStorage("profilePhotoData") private var profilePhotoData: Data   = Data()
    @AppStorage("profileName")      private var profileName:      String = ""
    @AppStorage("ageYears")         private var ageYears:         Int    = 0
    @AppStorage("heightCm")         private var heightCm:         Double = 0
    @AppStorage("manualWeightKg")   private var manualWeightKg:   Double = 0
    @AppStorage("useManualWeight")  private var useManualWeight:  Bool   = false
    @AppStorage("useImperial")      private var useImperial:      Bool   = false

    @AppStorage("lastCheckOutDate") private var lastCheckOutDate: String = ""

    @State private var selectedPhoto:    PhotosPickerItem?
    @State private var showingCheckOut:  Bool = false

    // MARK: - Derived

    private var displayWeight: Double? {
        if useManualWeight { return manualWeightKg > 0 ? manualWeightKg : nil }
        return healthKit.currentWeightKg ?? (manualWeightKg > 0 ? manualWeightKg : nil)
    }

    private var profileImage: Image? {
        guard !profilePhotoData.isEmpty,
              let ui = UIImage(data: profilePhotoData) else { return nil }
        return Image(uiImage: ui)
    }

    private var weightString: String {
        guard let w = displayWeight else { return "—" }
        if useImperial { return String(format: "%.0f", w * 2.20462) }
        return String(format: "%.0f", w)
    }

    private var heightString: String {
        guard heightCm > 0 else { return "—" }
        if useImperial {
            let totalInches = heightCm / 2.54
            let feet  = Int(totalInches / 12)
            let inch  = Int(totalInches.truncatingRemainder(dividingBy: 12))
            return "\(feet)'\(inch)\""
        }
        return String(format: "%.0f", heightCm)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            DS.Background.page.ignoresSafeArea()

            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    headerCard
                    menuCard
                    devCard
                    Spacer(minLength: DS.Spacing.xl)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)
            }
            .fullScreenCover(isPresented: $showingCheckOut) {
                EveningCheckOutView { showingCheckOut = false }
                    .environmentObject(healthKit)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhoto) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self),
                      let ui = UIImage(data: data) else { return }
                let size = CGSize(width: 200, height: 200)
                let renderer = UIGraphicsImageRenderer(size: size)
                let cropped = renderer.image { _ in
                    ui.draw(in: CGRect(origin: .zero, size: size))
                }
                if let jpg = cropped.jpegData(compressionQuality: 0.75) {
                    profilePhotoData = jpg
                }
            }
        }
    }

    // MARK: - Header card

    private var headerCard: some View {
        VStack(spacing: DS.Spacing.md) {

            // Photo with pencil overlay
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let img = profileImage {
                        img
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(AppColors.textMuted)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(AppColors.surface)
                    }
                }
                .frame(width: 90, height: 90)
                .clipShape(Circle())

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(AppColors.accent)
                        .background(
                            Circle()
                                .fill(DS.Background.card)
                                .frame(width: 22, height: 22)
                        )
                }
                .offset(x: 3, y: 3)
            }

            // Name
            Text(profileName.isEmpty ? "Tap pencil to add photo" : profileName)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(profileName.isEmpty ? AppColors.textMuted : AppColors.textPrimary)

            // Stats row
            HStack(spacing: 0) {
                statItem(value: weightString, label: useImperial ? "lbs" : "kg")
                Divider().frame(height: 32)
                statItem(value: heightString, label: useImperial ? "ft" : "cm")
                Divider().frame(height: 32)
                statItem(value: ageYears > 0 ? "\(ageYears)" : "—", label: "age")
            }
            .padding(.top, DS.Spacing.xs)
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(DS.Background.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
        .shadow(color: DS.Shadow.color, radius: DS.Shadow.radius, x: 0, y: DS.Shadow.y)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
            Text(label)
                .font(DS.Typography.caption())
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Menu card

    private var menuCard: some View {
        VStack(spacing: 0) {
            menuRow(
                icon: "person.text.rectangle.fill",
                iconColor: AppColors.accent,
                title: "Personal"
            ) { PersonalSettingsView() }

            Divider().padding(.leading, 56)

            menuRow(
                icon: "target",
                iconColor: AppColors.greenText,
                title: "Goals"
            ) { GoalsView() }

            Divider().padding(.leading, 56)

            menuRow(
                icon: "bell.fill",
                iconColor: AppColors.amberText,
                title: "Notifications"
            ) { NotificationsView() }

            Divider().padding(.leading, 56)

            menuRow(
                icon: "gearshape.fill",
                iconColor: AppColors.textMuted,
                title: "Settings"
            ) { SettingsView() }
        }
        .background(DS.Background.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
        .shadow(color: DS.Shadow.color, radius: DS.Shadow.radius, x: 0, y: DS.Shadow.y)
    }

    // MARK: - Dev card

    private var devCard: some View {
        Button {
            lastCheckOutDate = ""
            showingCheckOut  = true
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textMuted)
                    .frame(width: 36, height: 36)
                    .background(AppColors.metricInactive)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Preview check-out")
                        .font(DS.Typography.body())
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Dev only — resets today's lock")
                        .font(DS.Typography.caption())
                        .foregroundStyle(AppColors.textMuted)
                }
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
        }
        .buttonStyle(.plain)
        .background(DS.Background.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
        .shadow(color: DS.Shadow.color, radius: DS.Shadow.radius, x: 0, y: DS.Shadow.y)
    }

    @ViewBuilder
    private func menuRow<Dest: View>(
        icon: String,
        iconColor: Color,
        title: String,
        @ViewBuilder destination: () -> Dest
    ) -> some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 36, height: 36)
                    .background(iconColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(title)
                    .font(DS.Typography.body())
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.textMuted)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
