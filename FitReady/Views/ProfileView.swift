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

    @State private var selectedPhoto: PhotosPickerItem?

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
                    Spacer(minLength: DS.Spacing.xl)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)
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
                            .foregroundStyle(Color(.tertiaryLabel))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.quaternarySystemFill))
                    }
                }
                .frame(width: 90, height: 90)
                .clipShape(Circle())

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.purple)
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
                .foregroundStyle(profileName.isEmpty ? Color(.tertiaryLabel) : Color(.label))

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
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Menu card

    private var menuCard: some View {
        VStack(spacing: 0) {
            menuRow(
                icon: "person.text.rectangle.fill",
                iconColor: Color(hex: "5B4FCF"),
                title: "Personal"
            ) { PersonalSettingsView() }

            Divider().padding(.leading, 56)

            menuRow(
                icon: "target",
                iconColor: Color(hex: "1B7D38"),
                title: "Goals"
            ) { GoalsView() }

            Divider().padding(.leading, 56)

            menuRow(
                icon: "bell.fill",
                iconColor: Color(hex: "B45309"),
                title: "Notifications"
            ) { NotificationsView() }
        }
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
                    .foregroundStyle(Color(.label))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
        }
        .buttonStyle(.plain)
    }
}
