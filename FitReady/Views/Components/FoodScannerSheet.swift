import SwiftUI
import PhotosUI

// MARK: - Camera picker (UIImagePickerController wrapper)

struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPickerView
        init(_ p: CameraPickerView) { parent = p }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Scanner sheet

private enum ScannerPhase: Equatable {
    case pick
    case analysing
    case review(mealName: String, kcal: String, protein: String, fat: String, carbs: String)
    case error(String)
}

struct FoodScannerSheet: View {

    let apiKey:  String
    let todayKey: String
    let onSave:  (MealEntry) -> Void

    // Photo picker
    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showingCamera = false

    // Portion size
    @State private var portionSize = "medium"
    private let portionOptions = [("S", "small"), ("M", "medium"), ("L", "large")]

    // Flow
    @State private var phase: ScannerPhase = .pick

    // Review editable fields
    @State private var kcalText    = ""
    @State private var proteinText = ""
    @State private var fatText     = ""
    @State private var carbsText   = ""
    @State private var mealName    = ""

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    switch phase {
                    case .pick:
                        pickPhaseView
                    case .analysing:
                        analysingView
                    case .review:
                        reviewPhaseView
                    case .error(let msg):
                        errorView(message: msg)
                    }
                }
                .padding(20)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Scan Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraPickerView(image: $selectedImage)
                    .ignoresSafeArea()
            }
            .onChange(of: pickerItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let img  = UIImage(data: data) {
                        selectedImage = img
                    }
                }
            }
        }
    }

    // MARK: - Pick phase

    private var pickPhaseView: some View {
        VStack(spacing: 20) {
            // Image preview or placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.card)
                    .frame(height: 220)
                    .shadow(color: AppColors.shadowColor, radius: 8, x: 0, y: 2)

                if let img = selectedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Color(.tertiaryLabel))
                        Text("No photo selected")
                            .font(.subheadline)
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                }
            }

            // Photo source buttons
            HStack(spacing: 12) {
                Button {
                    showingCamera = true
                } label: {
                    Label("Camera", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.accent)

                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(AppColors.accent)
            }

            // Portion size picker
            VStack(alignment: .leading, spacing: 10) {
                Text("Portion size")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color(.secondaryLabel))

                HStack(spacing: 10) {
                    ForEach(portionOptions, id: \.0) { label, key in
                        let selected = portionSize == key
                        Button { portionSize = key } label: {
                            Text(label)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(selected ? AppColors.accent : AppColors.card)
                                .foregroundStyle(selected ? .white : Color(.label))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .shadow(color: .black.opacity(selected ? 0 : 0.05), radius: 4, x: 0, y: 1)
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(response: 0.3), value: portionSize)
                    }
                }
            }
            .padding(16)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: AppColors.shadowColor, radius: 8, x: 0, y: 2)

            // Analyse button
            Button {
                Task { await analyse() }
            } label: {
                Label("Analyse", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.accent)
            .disabled(selectedImage == nil)
            .controlSize(.large)
        }
    }

    // MARK: - Analysing phase

    private var analysingView: some View {
        VStack(spacing: 20) {
            if let img = selectedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: AppColors.shadowColor, radius: 8, x: 0, y: 2)
            }

            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.3)
                Text("Analysing your meal…")
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabel))
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: AppColors.shadowColor, radius: 8, x: 0, y: 2)
        }
    }

    // MARK: - Review phase

    private var reviewPhaseView: some View {
        VStack(spacing: 20) {
            if let img = selectedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: AppColors.shadowColor, radius: 8, x: 0, y: 2)
            }

            // Meal name header
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Estimate")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(Color(.tertiaryLabel))
                    .textCase(.uppercase)
                    .kerning(0.4)
                Text(mealName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(.label))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: AppColors.shadowColor, radius: 8, x: 0, y: 2)

            // Editable macro fields
            VStack(alignment: .leading, spacing: 14) {
                Text("Review & adjust")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(Color(.tertiaryLabel))
                    .textCase(.uppercase)
                    .kerning(0.4)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    reviewField(label: "Calories", unit: "kcal",
                                color: AppColors.dataCalories, text: $kcalText)
                    reviewField(label: "Protein",  unit: "g",
                                color: AppColors.dataProtein, text: $proteinText)
                    reviewField(label: "Fat",      unit: "g",
                                color: AppColors.dataFat, text: $fatText)
                    reviewField(label: "Carbs",    unit: "g",
                                color: AppColors.dataCarbs, text: $carbsText)
                }
            }
            .padding(16)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: AppColors.shadowColor, radius: 8, x: 0, y: 2)

            // Log button
            Button { saveAndDismiss() } label: {
                Label("Log Meal", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.accent)
            .controlSize(.large)
            .disabled(kcalText.isEmpty)

            // Re-scan option
            Button {
                phase = .pick
                selectedImage = nil
                pickerItem = nil
            } label: {
                Text("Start over")
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabel))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func reviewField(label: String, unit: String, color: Color, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text("\(label) (\(unit))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
                    .textCase(.uppercase)
                    .kerning(0.3)
            }
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color(.label))
        }
        .padding(12)
        .background(AppColors.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Error phase

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(AppColors.amberBase)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            Button {
                phase = .pick
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

    // MARK: - Actions

    private func analyse() async {
        guard let image = selectedImage else { return }
        phase = .analysing

        do {
            let result = try await AnthropicService.scanFood(
                image: image,
                portionSize: portionSize,
                apiKey: apiKey
            )
            mealName    = result.mealName
            kcalText    = String(Int(result.kcal.rounded()))
            proteinText = String(Int(result.proteinG.rounded()))
            fatText     = String(Int(result.fatG.rounded()))
            carbsText   = String(Int(result.carbsG.rounded()))
            phase = .review(
                mealName: result.mealName,
                kcal:    kcalText,
                protein: proteinText,
                fat:     fatText,
                carbs:   carbsText
            )
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    private func saveAndDismiss() {
        let entry = MealEntry(
            date:      todayKey,
            name:      mealName.isEmpty ? "Scanned meal" : mealName,
            kcal:      Double(kcalText)    ?? 0,
            proteinG:  Double(proteinText) ?? 0,
            fatG:      Double(fatText)     ?? 0,
            carbsG:    Double(carbsText)   ?? 0,
            source:    "scan"
        )
        onSave(entry)
        dismiss()
    }
}
