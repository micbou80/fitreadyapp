import SwiftUI
import PhotosUI
import AVFoundation

// MARK: - Camera session

final class CameraSession: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {

    enum AuthState { case unknown, authorized, denied }

    let session        = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue  = DispatchQueue(label: "com.fitready.camera", qos: .userInitiated)

    @Published var capturedImage: UIImage?
    @Published var authState: AuthState = .unknown

    func checkAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authState = .authorized
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.authState = granted ? .authorized : .denied
                    if granted { self?.configureAndRun() }
                }
            }
        default:
            DispatchQueue.main.async { self.authState = .denied }
        }
    }

    func stop() {
        queue.async { [weak self] in self?.session.stopRunning() }
    }

    func restart() {
        DispatchQueue.main.async { self.capturedImage = nil }
        queue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func capturePhoto() {
        output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    private func configureAndRun() {
        queue.async { [weak self] in
            guard let self else { return }
            if self.session.inputs.isEmpty {
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo
                if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                   let input  = try? AVCaptureDeviceInput(device: device),
                   self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
                if self.session.canAddOutput(self.output) {
                    self.session.addOutput(self.output)
                }
                self.session.commitConfiguration()
            }
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let data  = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        DispatchQueue.main.async { [weak self] in self?.capturedImage = image }
    }
}

// MARK: - Embedded live camera preview

struct LiveCameraView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.previewLayer.session      = session
        v.previewLayer.videoGravity = .resizeAspectFill
        if let c = v.previewLayer.connection, c.isVideoRotationAngleSupported(90) {
            c.videoRotationAngle = 90
        }
        return v
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

// MARK: - Viewfinder corner brackets

struct CornerBrackets: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let m: CGFloat = 36, l: CGFloat = 28
            Path { p in
                // Top-left
                p.move(to: CGPoint(x: m,         y: m + l)); p.addLine(to: CGPoint(x: m,     y: m)); p.addLine(to: CGPoint(x: m + l, y: m))
                // Top-right
                p.move(to: CGPoint(x: w - m - l, y: m));     p.addLine(to: CGPoint(x: w - m, y: m)); p.addLine(to: CGPoint(x: w - m, y: m + l))
                // Bottom-left
                p.move(to: CGPoint(x: m,         y: h - m - l)); p.addLine(to: CGPoint(x: m,     y: h - m)); p.addLine(to: CGPoint(x: m + l, y: h - m))
                // Bottom-right
                p.move(to: CGPoint(x: w - m - l, y: h - m)); p.addLine(to: CGPoint(x: w - m, y: h - m)); p.addLine(to: CGPoint(x: w - m, y: h - m - l))
            }
            .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - Scanner phase

private enum ScannerPhase: Equatable {
    case pick
    case textEntry
    case analysing
    case review
    case error(String)
}

// MARK: - Main scanner sheet

struct FoodScannerSheet: View {

    let apiKey:   String
    let todayKey: String
    let onSave:   (MealEntry) -> Void

    @StateObject private var cam = CameraSession()

    @State private var pickerItem:    PhotosPickerItem?
    @State private var selectedImage: UIImage?

    // Portion (review phase only)
    @State private var portionSize = "medium"
    private let portionOptions     = [("S", "small"), ("M", "medium"), ("L", "large")]
    private let portionMultiplier: [String: Double] = ["small": 0.65, "medium": 1.0, "large": 1.4]

    // AI baseline (medium estimate) for instant scaling
    @State private var baseKcal:    Double = 0
    @State private var baseProtein: Double = 0
    @State private var baseFat:     Double = 0
    @State private var baseCarbs:   Double = 0

    @State private var phase:           ScannerPhase = .pick
    @State private var textDescription: String       = ""
    @State private var kcalText    = ""
    @State private var proteinText = ""
    @State private var fatText     = ""
    @State private var carbsText   = ""
    @State private var mealName    = ""

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(navTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
        .presentationDetents([.large])
        .onAppear   { cam.checkAndStart() }
        .onDisappear { cam.stop() }
        // Camera captured → stop session, hand off to selectedImage
        .onChange(of: cam.capturedImage) { _, img in
            guard let img else { return }
            cam.stop()
            selectedImage = img
        }
        // Library photo loaded
        .onChange(of: pickerItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let img  = UIImage(data: data) {
                    selectedImage = img
                }
            }
        }
        // Any new image in pick phase → auto-analyse
        .onChange(of: selectedImage) { _, img in
            guard img != nil, case .pick = phase else { return }
            Task { await analyse() }
        }
        // Portion change → instant rescale
        .onChange(of: portionSize) { _, _ in applyPortionMultiplier() }
    }

    // MARK: - Phase router

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .pick:
            pickPhaseView
        default:
            ScrollView {
                VStack(spacing: 20) {
                    switch phase {
                    case .analysing:       analysingView
                    case .textEntry:       textEntryView
                    case .review:          reviewPhaseView
                    case .error(let msg):  errorView(message: msg)
                    default:               EmptyView()
                    }
                }
                .padding(20)
            }
            .background(AppColors.background.ignoresSafeArea())
        }
    }

    private var navTitle: String {
        switch phase {
        case .pick:      return "Scan Meal"
        case .textEntry: return "Add with Text"
        case .analysing: return "Analysing…"
        case .review:    return "Review"
        case .error:     return "Error"
        }
    }

    // MARK: - Pick phase (embedded camera)

    private var pickPhaseView: some View {
        VStack(spacing: 0) {

            // Live viewfinder
            ZStack {
                Color.black

                if cam.authState == .authorized {
                    LiveCameraView(session: cam.session)
                } else if cam.authState == .denied {
                    permissionDeniedOverlay
                }

                CornerBrackets()

                // Capture button at bottom of viewfinder
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
            .frame(height: 480)

            // Hint strip
            HStack(spacing: 0) {
                hintItem("arrow.down.to.line", "Hold above food")
                Spacer()
                hintItem("fork.knife",         "Separate all items")
                Spacer()
                hintItem("ruler",              "Add fork for scale")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(AppColors.surface)

            Divider()

            // Library + Menu Advisor
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

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

                    Divider()

                    NavigationLink {
                        MenuAdvisorView(apiKey: apiKey, todayKey: todayKey, onSave: onSave,
                                        onDismissAll: { dismiss() })
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "fork.knife.circle")
                                .font(.system(size: 18))
                                .foregroundStyle(AppColors.amberText)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Menu Advisor")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(AppColors.amberText)
                                Text("Photo a restaurant menu · get top 3 picks")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppColors.textMuted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppColors.textMuted)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }

                    Divider()

                    Button { phase = .textEntry } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "keyboard")
                                .font(.system(size: 18))
                                .foregroundStyle(AppColors.greenText)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Add with text")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(AppColors.textPrimary)
                                Text("Type what you ate · AI estimates macros")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppColors.textMuted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppColors.textMuted)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func hintItem(_ icon: String, _ label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
            Text(label)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(AppColors.textSecondary)
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

    // MARK: - Text entry phase

    private var textEntryView: some View {
        VStack(spacing: 20) {

            VStack(alignment: .leading, spacing: 10) {
                Text("DESCRIBE YOUR MEAL")
                    .font(DS.Typography.label())
                    .foregroundStyle(AppColors.textMuted)
                    .kerning(0.4)

                ZStack(alignment: .topLeading) {
                    if textDescription.isEmpty {
                        Text("e.g. Grilled chicken breast 200g, brown rice, side salad with olive oil")
                            .font(.system(size: 15))
                            .foregroundStyle(AppColors.textMuted)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $textDescription)
                        .font(.system(size: 15))
                        .frame(minHeight: 110)
                        .scrollContentBackground(.hidden)
                }
            }
            .padding(16)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: AppColors.shadowColor, radius: 8, x: 0, y: 2)

            Button {
                Task { await analyseFromText() }
            } label: {
                Label("Get Macros", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.accent)
            .controlSize(.large)
            .disabled(textDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button {
                phase = .pick
                textDescription = ""
            } label: {
                Text("Back")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .buttonStyle(.plain)
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
                ProgressView().scaleEffect(1.3)
                Text("Analysing your meal…")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
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

            // Meal name
            VStack(alignment: .leading, spacing: 4) {
                Text("AI ESTIMATE")
                    .font(DS.Typography.label())
                    .foregroundStyle(AppColors.textMuted)
                    .kerning(0.4)
                Text(mealName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: AppColors.shadowColor, radius: 8, x: 0, y: 2)

            // Portion size adjuster
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    Text("PORTION SIZE")
                        .font(DS.Typography.label())
                        .foregroundStyle(AppColors.textSecondary)
                        .kerning(0.5)
                    Spacer()
                    Text("Macros update automatically")
                        .font(.system(size: 10))
                        .foregroundStyle(AppColors.textMuted)
                }
                HStack(spacing: 10) {
                    ForEach(portionOptions, id: \.0) { label, key in
                        let selected = portionSize == key
                        Button { portionSize = key } label: {
                            Text(label)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(selected ? AppColors.accent : AppColors.background)
                                .foregroundStyle(selected ? AppColors.textOnBrand : AppColors.textPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
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

            // Editable macro fields
            VStack(alignment: .leading, spacing: 14) {
                Text("REVIEW & ADJUST")
                    .font(DS.Typography.label())
                    .foregroundStyle(AppColors.textMuted)
                    .kerning(0.4)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    reviewField(label: "Calories", unit: "kcal", color: AppColors.dataCalories, text: $kcalText)
                    reviewField(label: "Protein",  unit: "g",    color: AppColors.dataProtein,  text: $proteinText)
                    reviewField(label: "Fat",      unit: "g",    color: AppColors.dataFat,      text: $fatText)
                    reviewField(label: "Carbs",    unit: "g",    color: AppColors.dataCarbs,    text: $carbsText)
                }
            }
            .padding(16)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: AppColors.shadowColor, radius: 8, x: 0, y: 2)

            Button { saveAndDismiss() } label: {
                Label("Log Meal", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.accent)
            .controlSize(.large)
            .disabled(kcalText.isEmpty)

            Button {
                phase           = .pick
                selectedImage   = nil
                pickerItem      = nil
                textDescription = ""
                cam.restart()
            } label: {
                Text("Start over")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
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
                    .foregroundStyle(AppColors.textMuted)
                    .textCase(.uppercase)
                    .kerning(0.3)
            }
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
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
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            Button { phase = .pick } label: {
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

    private func analyseFromText() async {
        let desc = textDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !desc.isEmpty else { return }
        phase = .analysing
        do {
            let result  = try await AnthropicService.analyseText(description: desc, apiKey: apiKey)
            baseKcal    = result.kcal
            baseProtein = result.proteinG
            baseFat     = result.fatG
            baseCarbs   = result.carbsG
            mealName    = result.mealName
            portionSize = "medium"
            kcalText    = String(Int(result.kcal.rounded()))
            proteinText = String(Int(result.proteinG.rounded()))
            fatText     = String(Int(result.fatG.rounded()))
            carbsText   = String(Int(result.carbsG.rounded()))
            phase       = .review
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    private func analyse() async {
        guard let image = selectedImage else { return }
        phase = .analysing
        do {
            let result = try await AnthropicService.scanFood(
                image: image,
                portionSize: "medium",
                apiKey: apiKey
            )
            baseKcal    = result.kcal
            baseProtein = result.proteinG
            baseFat     = result.fatG
            baseCarbs   = result.carbsG
            mealName    = result.mealName
            portionSize = "medium"
            kcalText    = String(Int(result.kcal.rounded()))
            proteinText = String(Int(result.proteinG.rounded()))
            fatText     = String(Int(result.fatG.rounded()))
            carbsText   = String(Int(result.carbsG.rounded()))
            phase       = .review
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    private func applyPortionMultiplier() {
        let mult = portionMultiplier[portionSize] ?? 1.0
        kcalText    = String(Int((baseKcal    * mult).rounded()))
        proteinText = String(Int((baseProtein * mult).rounded()))
        fatText     = String(Int((baseFat     * mult).rounded()))
        carbsText   = String(Int((baseCarbs   * mult).rounded()))
    }

    private func saveAndDismiss() {
        let entry = MealEntry(
            date:     todayKey,
            name:     mealName.isEmpty ? "Scanned meal" : mealName,
            kcal:     Double(kcalText)    ?? 0,
            proteinG: Double(proteinText) ?? 0,
            fatG:     Double(fatText)     ?? 0,
            carbsG:   Double(carbsText)   ?? 0,
            source:   "scan"
        )
        onSave(entry)
        dismiss()
    }
}
