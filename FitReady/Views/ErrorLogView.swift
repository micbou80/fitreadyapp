import SwiftUI

/// In-app error log viewer for debugging production issues.
/// Accessible from Settings → Developer tools.
struct ErrorLogView: View {

    @State private var entries: [AppLogEntry] = []
    @State private var selectedLevel: AppLogEntry.LogLevel? = nil
    @State private var showClearConfirm = false
    @State private var expandedID: UUID? = nil

    private var filtered: [AppLogEntry] {
        guard let level = selectedLevel else { return entries }
        return entries.filter { $0.level == level }
    }

    var body: some View {
        ZStack {
            DS.Background.page.ignoresSafeArea()

            VStack(spacing: 0) {

                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.sm) {
                        filterChip(label: "All", level: nil)
                        ForEach(AppLogEntry.LogLevel.allCases, id: \.rawValue) { level in
                            filterChip(label: level.rawValue.capitalized, level: level)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)
                }

                Divider()

                if filtered.isEmpty {
                    Spacer()
                    VStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 36))
                            .foregroundStyle(AppColors.textMuted)
                        Text("No log entries")
                            .font(DS.Typography.body())
                            .foregroundStyle(AppColors.textMuted)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filtered) { entry in
                            entryRow(entry)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: DS.Spacing.lg, bottom: 4, trailing: DS.Spacing.lg))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Error Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showClearConfirm = true
                } label: {
                    Text("Clear")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppColors.danger)
                }
            }
        }
        .confirmationDialog("Clear all log entries?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear All", role: .destructive) {
                AppLogger.shared.clear()
                entries = []
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear { entries = AppLogger.shared.all() }
    }

    // MARK: - Filter chip

    @ViewBuilder
    private func filterChip(label: String, level: AppLogEntry.LogLevel?) -> some View {
        let isSelected = selectedLevel == level
        Button {
            selectedLevel = level
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? AppColors.textOnBrand : AppColors.textSecondary)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, 5)
                .background(isSelected ? AppColors.brandPrimary : AppColors.surface)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? AppColors.brandPrimary : DS.Border.color, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Entry row

    @ViewBuilder
    private func entryRow(_ entry: AppLogEntry) -> some View {
        let isExpanded = expandedID == entry.id
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.sm) {
                // Level indicator bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(levelColor(entry.level))
                    .frame(width: 3, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text(entry.tag)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(levelColor(entry.level))
                        Text("·")
                            .foregroundStyle(AppColors.textMuted)
                        Text(entry.timestamp, style: .time)
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundStyle(AppColors.textMuted)
                        Spacer()
                        Text(relativeDate(entry.timestamp))
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.textMuted)
                    }
                    Text(entry.message)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(isExpanded ? nil : 2)
                }
            }

            if let details = entry.details, isExpanded {
                Text(details)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(DS.Spacing.sm)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Corner.chip))
                    .textSelection(.enabled)
            }
        }
        .padding(DS.Spacing.sm)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DS.Corner.chip))
        .overlay(RoundedRectangle(cornerRadius: DS.Corner.chip).strokeBorder(DS.Border.color, lineWidth: 1))
        .onTapGesture {
            withAnimation(.spring(duration: 0.2)) {
                expandedID = isExpanded ? nil : entry.id
            }
        }
    }

    // MARK: - Helpers

    private func levelColor(_ level: AppLogEntry.LogLevel) -> Color {
        switch level {
        case .info:    return AppColors.info
        case .warning: return AppColors.warning
        case .error:   return AppColors.danger
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    // Seed some mock entries
    AppLogger.shared.log(level: .info,    tag: "HealthKit",    message: "Data loaded successfully",        details: nil)
    AppLogger.shared.log(level: .warning, tag: "FoodScanner",  message: "API key missing",                details: "anthropicAPIKey is empty")
    AppLogger.shared.log(level: .error,   tag: "WorkoutStore", message: "Failed to decode sessions JSON", details: "DecodingError: keyNotFound(CodingKeys(...), ...)")

    return NavigationStack {
        ErrorLogView()
    }
    .preferredColorScheme(.dark)
}
