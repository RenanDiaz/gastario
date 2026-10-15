import Foundation

/// Cuándo toca el auto-export y cómo se llama el archivo (`INTENT.md`, Respaldo; C5).
public enum BackupPolicy {
    public static let interval: TimeInterval = 7 * 24 * 60 * 60

    /// Nunca exportado → sí. Si no, desde 7 días exactos.
    public static func isDue(lastExportAt: Date?, now: Date) -> Bool {
        guard let lastExportAt else { return true }
        return now.timeIntervalSince(lastExportAt) >= interval
    }

    /// `Gastario-YYYY-MM-DD-HHmm.csv` en hora de Panamá. Se conservan todos (C5).
    public static func fileName(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Panama")!
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let stamp = String(
            format: "%04d-%02d-%02d-%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0)
        return "Gastario-\(stamp).csv"
    }
}

/// Estado del respaldo en el `UserDefaults` del App Group (C4). No vive en SwiftData: el export
/// no debe depender del store que respalda.
public struct BackupState {
    private let defaults: UserDefaults

    private enum Key {
        static let lastExportAt = "backup.lastExportAt"
        static let lastExportAttemptAt = "backup.lastExportAttemptAt"
        static let lastExportError = "backup.lastExportError"
    }

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public var lastExportAt: Date? {
        get { defaults.object(forKey: Key.lastExportAt) as? Date }
        nonmutating set { defaults.set(newValue, forKey: Key.lastExportAt) }
    }

    public var lastExportAttemptAt: Date? {
        get { defaults.object(forKey: Key.lastExportAttemptAt) as? Date }
        nonmutating set { defaults.set(newValue, forKey: Key.lastExportAttemptAt) }
    }

    public var lastExportError: String? {
        get { defaults.string(forKey: Key.lastExportError) }
        nonmutating set { defaults.set(newValue, forKey: Key.lastExportError) }
    }

    public func isDue(now: Date) -> Bool {
        BackupPolicy.isDue(lastExportAt: lastExportAt, now: now)
    }

    public func recordSuccess(at date: Date) {
        lastExportAttemptAt = date
        lastExportAt = date
        lastExportError = nil
    }

    /// El fallo no toca `lastExportAt`: se reintenta en la siguiente ejecución.
    public func recordFailure(_ message: String, at date: Date) {
        lastExportAttemptAt = date
        lastExportError = message
    }
}
