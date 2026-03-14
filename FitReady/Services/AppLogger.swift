import Foundation

// MARK: - Log entry

struct AppLogEntry: Codable, Identifiable {
    let id:        UUID
    let timestamp: Date
    let level:     LogLevel
    let tag:       String   // e.g. "HealthKit", "FoodScanner", "WorkoutStore"
    let message:   String
    let details:   String?  // Optional stack trace, response body, etc.

    enum LogLevel: String, Codable, CaseIterable {
        case info    = "info"
        case warning = "warning"
        case error   = "error"

        var emoji: String {
            switch self {
            case .info:    return "ℹ️"
            case .warning: return "⚠️"
            case .error:   return "🔴"
            }
        }
    }

    init(level: LogLevel, tag: String, message: String, details: String? = nil) {
        self.id        = UUID()
        self.timestamp = Date()
        self.level     = level
        self.tag       = tag
        self.message   = message
        self.details   = details
    }
}

// MARK: - AppLogger

/// Lightweight structured in-app log. Capped to 200 entries stored in UserDefaults.
/// Use `AppLogger.log(...)` anywhere in the app for diagnostic events.
final class AppLogger {

    static let shared = AppLogger()
    private init() {}

    private let key      = "appLogEntriesJSON"
    private let maxCount = 200

    // MARK: - Public API

    func log(level: AppLogEntry.LogLevel = .info, tag: String, message: String, details: String? = nil) {
        let entry = AppLogEntry(level: level, tag: tag, message: message, details: details)
        var entries = all()
        entries.insert(entry, at: 0)   // newest first
        if entries.count > maxCount { entries = Array(entries.prefix(maxCount)) }
        persist(entries)
    }

    func logError(_ error: Error, tag: String, context: String = "") {
        let msg     = context.isEmpty ? error.localizedDescription : context
        let details = "\(type(of: error)): \(error.localizedDescription)"
        log(level: .error, tag: tag, message: msg, details: details)
    }

    func all() -> [AppLogEntry] {
        guard let data   = UserDefaults.standard.string(forKey: key)?.data(using: .utf8),
              let entries = try? JSONDecoder().decode([AppLogEntry].self, from: data)
        else { return [] }
        return entries
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - Private

    private func persist(_ entries: [AppLogEntry]) {
        guard let data = try? JSONEncoder().encode(entries),
              let json = String(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(json, forKey: key)
    }
}
