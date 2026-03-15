import SwiftUI
import PhotosUI

struct ProfileView: View {

    @EnvironmentObject private var healthKit: HealthKitManager

    // Profile data
    @AppStorage("profilePhotoData")  private var profilePhotoData:  Data   = Data()
    @AppStorage("profileName")       private var profileName:       String = ""
    @AppStorage("primaryGoal")       private var primaryGoal:       String = "lose"
    @AppStorage("ageYears")          private var ageYears:          Int    = 0
    @AppStorage("heightCm")          private var heightCm:          Double = 0
    @AppStorage("goalWeightKg")      private var goalWeightKg:      Double = 0
    @AppStorage("manualWeightKg")    private var manualWeightKg:    Double = 0
    @AppStorage("useManualWeight")   private var useManualWeight:   Bool   = false
    @AppStorage("useImperial")       private var useImperial:       Bool   = false

    // Preferences
    @AppStorage("prefersDarkMode")   private var prefersDarkMode:   Bool   = false
    @AppStorage("notificationLevel") private var notificationLevel: String = "moderate"

    // Status
    @AppStorage("userStatus")        private var userStatus: String = "active"

    // Dev / state
    @AppStorage("lastCheckOutDate")    private var lastCheckOutDate:    String = ""
    @AppStorage("onboardingCompleted") private var onboardingCompleted: Bool   = false
    @AppStorage("anthropicAPIKey")     private var anthropicAPIKey:     String = ""

    @State private var selectedPhoto:       PhotosPickerItem?
    @State private var rawPhotoUIImage:     UIImage?    = nil
    @State private var showingCropSheet:    Bool        = false
    @State private var showingCheckOut:     Bool = false
    @State private var showingOnboarding:   Bool = false
    @State private var showingResetConfirm: Bool = false
    @State private var showingAPIKey:       Bool = false
    @State private var showingStatusPicker: Bool = false

    // MARK: - Hero palette (always dark, like TodayHeroSection)

    private let heroText  = Color(hex: "F2F2F2")
    private let heroSub   = Color(hex: "F2F2F2").opacity(0.70)
    private let heroMuted = Color(hex: "F2F2F2").opacity(0.45)

    // MARK: - Derived

    private var profileImage: Image? {
        guard !profilePhotoData.isEmpty,
              let ui = UIImage(data: profilePhotoData) else { return nil }
        return Image(uiImage: ui)
    }

    private var goalTagline: String {
        switch primaryGoal {
        case "lose":     return "On a mission to lose weight"
        case "muscle":   return "On a mission to build muscle"
        case "gain":     return "On a mission to get fitter"
        case "maintain": return "On a mission to maintain"
        default:         return "On a mission to stay healthy"
        }
    }

    private var displayWeight: Double? {
        if useManualWeight { return manualWeightKg > 0 ? manualWeightKg : nil }
        return healthKit.currentWeightKg ?? (manualWeightKg > 0 ? manualWeightKg : nil)
    }

    /// 0–1 fill for the goal progress bar.
    /// Fills as the user gets CLOSER to their goal weight, regardless of direction.
    /// 0% = maxJourney kg away; 100% = at goal.
    private var goalProgressValue: Double {
        guard let current = displayWeight, current > 0, goalWeightKg > 0 else { return 0 }
        let maxJourney: Double = useImperial ? 44.0 : 20.0   // 20 kg / 44 lbs cap
        let remaining = abs(current - goalWeightKg)
        return max(0.0, min(1.0, 1.0 - remaining / maxJourney))
    }

    /// Human-readable sub-label under the progress bar.
    private var goalProgressLabel: String {
        guard let current = displayWeight, goalWeightKg > 0 else {
            return "Set a goal weight in My Goals"
        }
        let diff = current - goalWeightKg
        if abs(diff) < 0.4 { return "Goal reached — amazing work!" }
        let val  = useImperial ? abs(diff * 2.20462) : abs(diff)
        let unit = useImperial ? "lbs" : "kg"
        let dir  = diff > 0 ? "to lose" : "to gain"
        return String(format: "%.1f %@ %@", val, unit, dir)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            DS.Background.page.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {

                    heroCard
                        .padding(.horizontal, DS.Spacing.xl)
                        .padding(.top, DS.Spacing.xl)
                        .padding(.bottom, DS.Spacing.xl)

                    statusSection

                    sectionGroup(title: "Account") {
                        menuRow(icon: "person.text.rectangle.fill",
                                title: "Profile data") { PersonalSettingsView() }
                        divider
                        menuRow(icon: "target",
                                title: "My goals") { GoalsView() }
                    }

                    sectionGroup(title: "Preferences") {
                        toggleRow(icon: "moon.fill",
                                  title: "Dark mode",
                                  isOn: $prefersDarkMode)
                        divider
                        menuRow(icon: "bell.fill",
                                title: "Notification settings") { NotificationsView() }
                        divider
                        notificationsToggleRow
                    }

                    sectionGroup(title: "Help") {
                        actionRow(icon: "envelope.fill",
                                  title: "Contact support") {
                            if let url = URL(string: "mailto:support@fitready.app") {
                                UIApplication.shared.open(url)
                            }
                        }
                        divider
                        placeholderRow(icon: "star.bubble.fill",
                                       title: "Submit feature request")
                        divider
                        placeholderRow(icon: "hand.raised.fill",
                                       title: "Privacy center")
                    }

                    sectionGroup(title: "Developer") {
                        actionRow(icon: "key.fill",
                                  title: "Anthropic API key") { showingAPIKey = true }
                        divider
                        devMenuRow
                    }

                    Spacer(minLength: DS.Spacing.xl * 2)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $showingCheckOut) {
            EveningCheckOutView { showingCheckOut = false }
                .environmentObject(healthKit)
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingView { showingOnboarding = false }
        }
        .sheet(isPresented: $showingStatusPicker) {
            SetStatusSheet(userStatus: $userStatus)
        }
        .sheet(isPresented: $showingAPIKey) {
            APIKeySheet(apiKey: $anthropicAPIKey)
        }
        .sheet(isPresented: $showingCropSheet) {
            if let img = rawPhotoUIImage {
                CropImageSheet(image: img) { croppedData in
                    profilePhotoData = croppedData
                }
            }
        }
        .alert("Reset everything?", isPresented: $showingResetConfirm) {
            Button("Reset", role: .destructive) {
                ICloudSyncService.shared.nukeAll()
                onboardingCompleted = false
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Wipes all data from UserDefaults and iCloud. Onboarding will show on next launch.")
        }
        .onChange(of: selectedPhoto) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self),
                      let full = UIImage(data: data) else { return }
                // Downsample to 1 200 px max — crop output is 400 px so this is 3× headroom.
                // byPreparingThumbnail is hardware-accelerated; avoids holding a 40+ MP image in memory.
                let maxSide: CGFloat = 1_200
                let longest  = max(full.size.width, full.size.height)
                let target   = longest > maxSide
                    ? CGSize(width:  full.size.width  * maxSide / longest,
                             height: full.size.height * maxSide / longest)
                    : full.size
                rawPhotoUIImage  = await full.byPreparingThumbnail(ofSize: target) ?? full
                showingCropSheet = true
            }
        }
    }

    // MARK: - Hero card

    private var heroCard: some View {
        let avatarSize: CGFloat = 108
        let overlap: CGFloat    = 48

        return ZStack(alignment: .top) {

            // ── Card body (offset down so avatar can float above) ──────────────
            ZStack {
                Color(hex: "20422E")
                AppColors.brandPrimary.opacity(0.08)

                VStack(spacing: DS.Spacing.md) {

                    // Space reserved for the floating avatar
                    Spacer().frame(height: avatarSize - overlap + DS.Spacing.sm)

                    // Name + goal
                    VStack(spacing: 4) {
                        Text(profileName.isEmpty ? "Add your name" : profileName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(profileName.isEmpty ? heroMuted : heroText)

                        Text(profileName.isEmpty ? "Tap to complete your profile" : goalTagline)
                            .font(.system(size: 13))
                            .foregroundStyle(heroSub)
                            .multilineTextAlignment(.center)

                        // Status chip — only surfaced when non-active
                        let currentStatus = UserStatus.from(userStatus)
                        if currentStatus != .active {
                            HStack(spacing: 5) {
                                Image(systemName: currentStatus.icon)
                                    .font(.system(size: 11, weight: .medium))
                                Text(currentStatus.label)
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(heroText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(currentStatus.color.opacity(0.28))
                            .clipShape(Capsule())
                            .padding(.top, 4)
                        }
                    }

                    // Goal progress bar
                    VStack(spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Goal Progress")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(heroSub)
                            Spacer()
                            Text("\(Int(goalProgressValue * 100))%")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(heroText)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(AppColors.brandPrimary.opacity(0.18))
                                    .frame(height: 7)
                                Capsule()
                                    .fill(AppColors.brandPrimary)
                                    .frame(width: geo.size.width * goalProgressValue, height: 7)
                            }
                        }
                        .frame(height: 7)

                        Text(goalProgressLabel)
                            .font(.system(size: 11))
                            .foregroundStyle(heroMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.bottom, DS.Spacing.md)
                }
                .padding(.horizontal, DS.Spacing.lg)
            }
            .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
            .shadow(color: DS.Shadow.color, radius: DS.Shadow.radius, x: 0, y: DS.Shadow.y)
            .padding(.top, overlap)

            // ── Avatar floating at the top centre ─────────────────────────────
            HStack {
                Spacer()
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let img = profileImage {
                            img.resizable().scaledToFill()
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(heroMuted)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(AppColors.brandPrimary.opacity(0.12))
                        }
                    }
                    .frame(width: avatarSize, height: avatarSize)
                    .clipShape(Circle())
                    // Outer ring matches page background so it "floats" cleanly
                    .overlay(Circle().strokeBorder(AppColors.background, lineWidth: 3))
                    .overlay(Circle().strokeBorder(AppColors.brandPrimary.opacity(0.35), lineWidth: 1.5))

                    // Edit button
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        ZStack {
                            Circle()
                                .fill(AppColors.brandPrimary)
                                .frame(width: 30, height: 30)
                            Image(systemName: "pencil")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppColors.textOnBrand)
                        }
                    }
                    .offset(x: 4, y: 4)
                }
                Spacer()
            }
        }
    }

    // MARK: - Status section

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("STATUS".uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
                .kerning(0.5)
                .padding(.horizontal, DS.Spacing.lg + DS.Spacing.sm)
                .padding(.top, DS.Spacing.sm)

            Button { showingStatusPicker = true } label: {
                HStack(spacing: DS.Spacing.md) {
                    let status = UserStatus.from(userStatus)
                    Image(systemName: status.icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(status == .active ? AppColors.textPrimary : status.color)
                        .frame(width: 32, height: 32)
                        .background(status == .active ? AppColors.accentGold.opacity(0.18) : status.color.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(UserStatus.from(userStatus).label)
                            .font(DS.Typography.body())
                            .foregroundStyle(AppColors.textPrimary)
                        Text(UserStatus.from(userStatus).tagline)
                            .font(DS.Typography.caption())
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.textMuted)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
                .shadow(color: DS.Shadow.color, radius: DS.Shadow.radius, x: 0, y: DS.Shadow.y)
                .padding(.horizontal, DS.Spacing.lg)
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 2)
    }

    // MARK: - Section group

    private func sectionGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
                .kerning(0.5)
                .padding(.horizontal, DS.Spacing.lg + DS.Spacing.sm)
                .padding(.top, DS.Spacing.sm)

            VStack(spacing: 0) {
                content()
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
            .shadow(color: DS.Shadow.color, radius: DS.Shadow.radius, x: 0, y: DS.Shadow.y)
            .padding(.horizontal, DS.Spacing.lg)
        }
        .padding(.bottom, 2)
    }

    private var divider: some View {
        Divider().padding(.leading, 56)
    }

    // MARK: - Row types

    @ViewBuilder
    private func menuRow<Dest: View>(
        icon: String,
        title: String,
        @ViewBuilder destination: () -> Dest
    ) -> some View {
        NavigationLink(destination: destination()) {
            rowContent(icon: icon, title: title, trailing: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.textMuted)
            })
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        rowContent(icon: icon, title: title, trailing: {
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(AppColors.brandPrimary)
        })
    }

    private func actionRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            rowContent(icon: icon, title: title, trailing: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.textMuted)
            })
        }
        .buttonStyle(.plain)
    }

    private func placeholderRow(icon: String, title: String) -> some View {
        rowContent(icon: icon, title: title, trailing: {
            Text("Soon")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.textMuted)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(AppColors.surface)
                .clipShape(Capsule())
        })
    }

    private func rowContent<Trailing: View>(
        icon: String,
        title: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 32, height: 32)
                .background(AppColors.accentGold.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(title)
                .font(DS.Typography.body())
                .foregroundStyle(AppColors.textPrimary)

            Spacer()

            trailing()
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
        .contentShape(Rectangle())
    }

    // MARK: - Specialised rows

    private var notificationsToggleRow: some View {
        rowContent(icon: "bell.badge.fill", title: "Receive notifications", trailing: {
            Toggle("", isOn: Binding(
                get: { notificationLevel != "off" },
                set: { enabled in
                    if enabled {
                        notificationLevel = "moderate"
                        NotificationManager.shared.requestPermission()
                        NotificationManager.shared.reschedule(level: "moderate")
                    } else {
                        notificationLevel = "off"
                        NotificationManager.shared.reschedule(level: "off")
                    }
                }
            ))
            .labelsHidden()
            .tint(AppColors.brandPrimary)
        })
    }

    private var devMenuRow: some View {
        Menu {
            Button {
                lastCheckOutDate = ""
                showingCheckOut  = true
            } label: {
                Label("Preview check-out", systemImage: "arrow.counterclockwise")
            }
            Button {
                showingOnboarding = true
            } label: {
                Label("Preview onboarding", systemImage: "sparkles")
            }
            Divider()
            Button(role: .destructive) {
                showingResetConfirm = true
            } label: {
                Label("Reset everything", systemImage: "trash")
            }
        } label: {
            rowContent(icon: "hammer.fill", title: "Developer tools", trailing: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.textMuted)
            })
        }
    }
}

// MARK: - Set Status Sheet

private struct SetStatusSheet: View {

    @Binding var userStatus: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppColors.bg.ignoresSafeArea()

            VStack(spacing: 0) {

                // Title
                Text("Set Status")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.xl)
                    .padding(.bottom, DS.Spacing.lg)

                // Status rows
                VStack(spacing: DS.Spacing.sm) {
                    ForEach(UserStatus.allCases, id: \.rawValue) { status in
                        statusRow(status)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)

                Spacer()

                // Done button
                Button {
                    Haptics.impact(.light)
                    dismiss()
                } label: {
                    Text("DONE")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                        .background(AppColors.raised)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Corner.button))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xl)
            }
        }
    }

    @ViewBuilder
    private func statusRow(_ status: UserStatus) -> some View {
        let isSelected = userStatus == status.rawValue

        Button {
            userStatus = status.rawValue
            Haptics.impact(.light)
        } label: {
            HStack(spacing: DS.Spacing.md) {

                // Icon
                Image(systemName: status.icon)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(isSelected ? AppColors.brandPrimary : AppColors.textSecondary)
                    .frame(width: 28)

                // Text block
                VStack(alignment: .leading, spacing: 3) {
                    Text(status.label)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text(status.tagline)
                        .font(DS.Typography.caption())
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                // Radio button
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(AppColors.brandPrimary)
                            .frame(width: 22, height: 22)
                        Circle()
                            .fill(AppColors.textOnBrand)
                            .frame(width: 8, height: 8)
                    } else {
                        Circle()
                            .strokeBorder(AppColors.border, lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .frame(minHeight: 70)
            .background(isSelected ? AppColors.raised : AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - API Key Sheet

private struct APIKeySheet: View {
    @Binding var apiKey: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Paste your key here", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Link(destination: URL(string: "https://console.anthropic.com/settings/keys")!) {
                        HStack {
                            Text("Get a free API key")
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                        .foregroundStyle(AppColors.accent)
                    }
                } header: {
                    Text("Anthropic API Key")
                } footer: {
                    Text("Used for meal photo analysis. Stored locally and never shared.")
                }
            }
            .navigationTitle("API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Crop Image Sheet

private struct CropImageSheet: View {

    let image:  UIImage
    let onSave: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    private let cropSize: CGFloat = 290

    @State private var scale:      CGFloat = 1.0
    @State private var lastScale:  CGFloat = 1.0
    @State private var offset:     CGSize  = .zero
    @State private var lastOffset: CGSize  = .zero

    private var baseSize: CGSize {
        let a = image.size.width / image.size.height
        return a > 1
            ? CGSize(width: cropSize * a, height: cropSize)
            : CGSize(width: cropSize,     height: cropSize / a)
    }

    var body: some View {
        // No NavigationStack — we build the chrome manually so Color.black owns the background.
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Manual top bar ─────────────────────────────────────────────
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.white.opacity(0.14))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("Adjust Photo")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)   // balance
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer()

                // ── Crop area ─────────────────────────────────────────────────
                ZStack {
                    // Full-bleed image under the overlay so panning feels natural
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cropSize, height: cropSize)
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: cropSize, height: cropSize)
                        .clipped()
                        .clipShape(Circle())

                    // Subtle circle border guide
                    Circle()
                        .strokeBorder(.white.opacity(0.40), lineWidth: 1.5)
                        .frame(width: cropSize, height: cropSize)
                        .allowsHitTesting(false)
                }

                Spacer()

                // ── Bottom section ────────────────────────────────────────────
                VStack(spacing: 20) {

                    // Info card
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.55))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Photo preview")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Pinch to zoom and drag to reposition.")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.60))
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // Action row
                    HStack {
                        Button("Edit photo") { dismiss() }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))

                        Spacer()

                        Button("Save photo") { crop() }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppColors.textOnBrand)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 14)
                            .background(AppColors.brandPrimary)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
            }
        }
        .gesture(
            MagnificationGesture()
                .onChanged { scale = max(1.0, lastScale * $0) }
                .onEnded   { _ in lastScale = scale; clampOffset() }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    offset = CGSize(
                        width:  lastOffset.width  + drag.translation.width,
                        height: lastOffset.height + drag.translation.height
                    )
                }
                .onEnded { _ in lastOffset = offset; clampOffset() }
        )
        .presentationBackground(Color.black)
    }

    private func clampOffset() {
        let b    = baseSize
        let maxX = max(0, (b.width  * scale - cropSize) / 2)
        let maxY = max(0, (b.height * scale - cropSize) / 2)
        offset     = CGSize(width:  min(maxX, max(-maxX, offset.width)),
                            height: min(maxY, max(-maxY, offset.height)))
        lastOffset = offset
    }

    private func crop() {
        let side  = 400
        let ratio = CGFloat(side) / cropSize
        UIGraphicsBeginImageContextWithOptions(CGSize(width: side, height: side), false, 1.0)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        ctx.addEllipse(in: CGRect(x: 0, y: 0, width: side, height: side))
        ctx.clip()

        let b       = baseSize
        let scaledW = b.width  * scale
        let scaledH = b.height * scale
        let drawX   = (cropSize - scaledW) / 2 + offset.width
        let drawY   = (cropSize - scaledH) / 2 + offset.height

        image.draw(in: CGRect(x: drawX * ratio, y: drawY * ratio,
                              width: scaledW * ratio, height: scaledH * ratio))

        if let result = UIGraphicsGetImageFromCurrentImageContext(),
           let jpg    = result.jpegData(compressionQuality: 0.85) {
            onSave(jpg)
            dismiss()
        }
    }
}
