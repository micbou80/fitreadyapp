import SwiftUI

/// Personal info: name, birthday, sex, height, weight, training days/location, activity level.
struct PersonalSettingsView: View {

    @AppStorage("profileName")         private var profileName:         String = ""
    @AppStorage("profileBirthdayTS")   private var birthdayTS:          Double = 0
    @AppStorage("ageYears")            private var ageYears:            Int    = 0
    @AppStorage("biologicalSex")       private var biologicalSex:       String = ""
    @AppStorage("heightCm")            private var heightCm:            Double = 0
    @AppStorage("manualWeightKg")      private var manualWeightKg:      Double = 0
    @AppStorage("useManualWeight")     private var useManualWeight:     Bool   = false
    @AppStorage("trainingDaysPerWeek") private var trainingDaysPerWeek: Int    = 4
    @AppStorage("trainingLocation")    private var trainingLocation:    String = "gym"
    @AppStorage("activityLevel")       private var activityLevel:       String = "moderate"
    @AppStorage("useImperial")         private var useImperial:         Bool   = false

    @State private var nameText:    String = ""
    @State private var heightText:  String = ""
    @State private var weightText:  String = ""
    @State private var birthday:    Date   = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    @State private var showDatePicker = false
    @State private var saved = false

    @FocusState private var focusedField: Field?
    private enum Field { case name, height, weight }

    // MARK: - Body

    var body: some View {
        ZStack {
            DS.Background.page.ignoresSafeArea()
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {

                    // ── Identity ──────────────────────────────────────
                    settingsCard {
                        sectionLabel("Identity")

                        settingRow(icon: "person.fill", iconColor: AppColors.accent, label: "Name") {
                            TextField("Your name", text: $nameText)
                                .multilineTextAlignment(.trailing)
                                .focused($focusedField, equals: .name)
                        }

                        Divider().padding(.leading, 52)

                        // Birthday row — taps to open inline DatePicker
                        Button { showDatePicker.toggle(); focusedField = nil } label: {
                            HStack(spacing: DS.Spacing.md) {
                                Image(systemName: "birthday.cake.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(AppColors.amberText)
                                    .frame(width: 28, height: 28)
                                    .background(AppColors.amberText.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                Text("Birthday")
                                    .font(DS.Typography.body())
                                    .foregroundStyle(Color(.label))
                                Spacer()
                                Text(birthdayTS > 0 ? birthdayFormatted : "Not set")
                                    .font(DS.Typography.body())
                                    .foregroundStyle(birthdayTS > 0 ? Color(.label) : Color(.tertiaryLabel))
                                Image(systemName: showDatePicker ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color(.tertiaryLabel))
                            }
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.vertical, DS.Spacing.md)
                        }
                        .buttonStyle(.plain)

                        if showDatePicker {
                            DatePicker(
                                "",
                                selection: $birthday,
                                in: ...Calendar.current.date(byAdding: .year, value: -10, to: Date())!,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .tint(AppColors.accent)
                            .padding(.horizontal, DS.Spacing.md)
                        }

                        Divider().padding(.leading, 52)

                        settingRow(icon: "person.2.fill", iconColor: AppColors.greenText, label: "Biological sex") {
                            Picker("", selection: $biologicalSex) {
                                Text("Male").tag("male")
                                Text("Female").tag("female")
                                Text("Prefer not to say").tag("")
                            }
                            .pickerStyle(.menu)
                            .tint(AppColors.accent)
                        }
                    }

                    // ── Body measurements ─────────────────────────────
                    settingsCard {
                        sectionLabel("Body Measurements")

                        settingRow(
                            icon: "ruler.fill",
                            iconColor: AppColors.accent,
                            label: useImperial ? "Height (ft'in\")" : "Height (cm)"
                        ) {
                            TextField(useImperial ? "5'10\"" : "175", text: $heightText)
                                .keyboardType(.numbersAndPunctuation)
                                .multilineTextAlignment(.trailing)
                                .focused($focusedField, equals: .height)
                                .frame(width: 80)
                        }

                        Divider().padding(.leading, 52)

                        settingRow(
                            icon: "scalemass.fill",
                            iconColor: AppColors.amberText,
                            label: useImperial ? "Weight (lbs)" : "Weight (kg)"
                        ) {
                            TextField(useImperial ? "175" : "80", text: $weightText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .focused($focusedField, equals: .weight)
                                .frame(width: 80)
                        }

                        Divider().padding(.leading, 52)

                        HStack(spacing: DS.Spacing.md) {
                            Image(systemName: "globe.americas.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color(.secondaryLabel))
                                .frame(width: 28, height: 28)
                                .background(Color(.secondaryLabel).opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            Text("Imperial units")
                                .font(DS.Typography.body())
                            Spacer()
                            Toggle("", isOn: $useImperial)
                                .labelsHidden()
                                .tint(AppColors.accent)
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.md)
                    }

                    // ── Training ──────────────────────────────────────
                    settingsCard {
                        sectionLabel("Training")

                        settingRow(icon: "calendar", iconColor: AppColors.greenText, label: "Days per week") {
                            Picker("", selection: $trainingDaysPerWeek) {
                                ForEach(1...7, id: \.self) { Text("\($0) days").tag($0) }
                            }
                            .pickerStyle(.menu)
                            .tint(AppColors.accent)
                        }

                        Divider().padding(.leading, 52)

                        settingRow(icon: "building.2.fill", iconColor: AppColors.accent, label: "Location") {
                            Picker("", selection: $trainingLocation) {
                                Text("Gym").tag("gym")
                                Text("Home").tag("home")
                                Text("Mix").tag("mix")
                            }
                            .pickerStyle(.menu)
                            .tint(AppColors.accent)
                        }

                        Divider().padding(.leading, 52)

                        settingRow(icon: "figure.run", iconColor: AppColors.amberText, label: "Activity level") {
                            Picker("", selection: $activityLevel) {
                                Text("Sedentary").tag("sedentary")
                                Text("Lightly Active").tag("light")
                                Text("Moderately Active").tag("moderate")
                                Text("Very Active").tag("active")
                            }
                            .pickerStyle(.menu)
                            .tint(AppColors.accent)
                        }
                    }

                    // ── Save button ───────────────────────────────────
                    Button(action: save) {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: saved ? "checkmark.circle.fill" : "square.and.arrow.down.fill")
                            Text(saved ? "Saved" : "Save Changes")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                        .background(saved ? AppColors.greenText : AppColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Corner.button))
                    }
                    .animation(.easeInOut(duration: 0.3), value: saved)

                    Spacer(minLength: DS.Spacing.xl)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)
            }
            .simultaneousGesture(TapGesture().onEnded { focusedField = nil })
        }
        .navigationTitle("Personal")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadFields() }
    }

    // MARK: - Computed

    private var birthdayFormatted: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        return fmt.string(from: Date(timeIntervalSince1970: birthdayTS))
    }

    // MARK: - Load / Save

    private func loadFields() {
        nameText = profileName
        if birthdayTS > 0 { birthday = Date(timeIntervalSince1970: birthdayTS) }
        if heightCm > 0 {
            if useImperial {
                let totalInches = heightCm / 2.54
                let ft = Int(totalInches / 12)
                let inch = Int(totalInches.truncatingRemainder(dividingBy: 12))
                heightText = "\(ft)'\(inch)\""
            } else {
                heightText = String(format: "%.0f", heightCm)
            }
        }
        if manualWeightKg > 0 {
            weightText = useImperial
                ? String(format: "%.0f", manualWeightKg * 2.20462)
                : String(format: "%.1f", manualWeightKg)
        }
    }

    private func save() {
        // Name
        profileName = nameText.trimmingCharacters(in: .whitespaces)

        // Birthday → ageYears
        birthdayTS = birthday.timeIntervalSince1970
        if let years = Calendar.current.dateComponents([.year], from: birthday, to: Date()).year {
            ageYears = years
        }
        showDatePicker = false

        // Height
        if useImperial {
            // Accept "5'10\"" or "5'10" or just inches
            let cleaned = heightText.replacingOccurrences(of: "\"", with: "")
            let parts = cleaned.split(separator: "'")
            if parts.count == 2,
               let ft = Double(parts[0].trimmingCharacters(in: .whitespaces)),
               let inch = Double(parts[1].trimmingCharacters(in: .whitespaces)) {
                heightCm = (ft * 12 + inch) * 2.54
            } else if let inch = Double(cleaned.trimmingCharacters(in: .whitespaces)) {
                heightCm = inch * 2.54
            }
        } else {
            if let h = Double(heightText.replacingOccurrences(of: ",", with: ".")) { heightCm = h }
        }

        // Weight
        if useImperial {
            if let lbs = Double(weightText.replacingOccurrences(of: ",", with: ".")) {
                manualWeightKg = lbs / 2.20462
                useManualWeight = true
            }
        } else {
            if let kg = Double(weightText.replacingOccurrences(of: ",", with: ".")) {
                manualWeightKg = kg
                useManualWeight = true
            }
        }

        Haptics.notification(.success)
        withAnimation { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { saved = false } }
        focusedField = nil
    }

    // MARK: - Layout helpers

    @ViewBuilder
    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(DS.Background.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
            .shadow(color: DS.Shadow.color, radius: DS.Shadow.radius, x: 0, y: DS.Shadow.y)
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color(.secondaryLabel))
            .kerning(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.xs)
    }

    @ViewBuilder
    private func settingRow<Trailing: View>(
        icon: String,
        iconColor: Color,
        label: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Text(label)
                .font(DS.Typography.body())
            Spacer()
            trailing()
                .foregroundStyle(Color(.secondaryLabel))
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }
}
