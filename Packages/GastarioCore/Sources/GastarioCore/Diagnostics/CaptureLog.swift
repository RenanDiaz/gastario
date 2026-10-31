import Foundation
import OSLog

/// Bitácora de captura (SPEC Fase 7a, C17): `capture-YYYY-MM.jsonl` en un directorio del App
/// Group, una línea JSON por evento. Vive fuera de SwiftData para que un problema del store no
/// se la lleve (mismo argumento que C4).
///
/// Nunca lanza: un error de escritura solo va a OSLog, porque la bitácora no puede hacer fallar
/// ni retrasar una captura (principio 1).
///
/// `@MainActor`, igual que los intents y la UI que la usan: las escrituras de un proceso no se
/// intercalan.
@MainActor
public final class CaptureLog {
    public let directory: URL
    private let version: String
    private let build: String
    private let now: () -> Date
    private var wroteProcess = false
    private let logger = Logger(subsystem: "com.renandiaz.Gastario", category: "capture-log")

    /// Meses que se conservan, contando el actual.
    public static let retainedMonths = 3

    public init(directory: URL, version: String, build: String, now: @escaping () -> Date = { .now }) {
        self.directory = directory
        self.version = version
        self.build = build
        self.now = now
    }

    /// Escribe el evento con la hora y el `pid` actuales. La primera vez en cada instancia
    /// escribe antes un `process`.
    public func record(_ event: CaptureLogEvent) {
        let pid = ProcessInfo.processInfo.processIdentifier
        let date = now()
        if !wroteProcess {
            wroteProcess = true
            var process = CaptureLogEvent.process(version: version, build: build)
            process.t = date
            process.pid = pid
            append(process)
        }
        var event = event
        event.t = date
        event.pid = pid
        append(event)
    }

    /// Cada evento se escribe completo y se sincroniza a disco antes de seguir: si iOS mata el
    /// proceso, lo anterior ya quedó.
    private func append(_ event: CaptureLogEvent) {
        do {
            var data = try CaptureLogCoding.encoder().encode(event)
            data.append(0x0A)
            let url = fileURL(for: event.t)
            let fileManager = FileManager.default
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            if !fileManager.fileExists(atPath: url.path(percentEncoded: false)) {
                _ = fileManager.createFile(atPath: url.path(percentEncoded: false), contents: nil)
            }
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.synchronize()
        } catch {
            logger.error("No se pudo escribir la bitácora: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Archivos de la bitácora, del más viejo al más nuevo.
    public func files() -> [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false))) ?? []
        return names
            .filter { Self.monthKey(ofFileName: $0) != nil }
            .sorted()
            .map { directory.appending(path: $0) }
    }

    /// Todas las líneas de todos los archivos, en orden.
    public func lines() -> [String] {
        files().flatMap { url -> [Substring] in
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
            return text.split(separator: "\n")
        }
        .map(String.init)
    }

    /// Borra los meses que quedaron fuera de `retainedMonths`. Solo toca `capture-*.jsonl`.
    public func prune() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = CaptureLogCoding.panama
        guard let oldest = calendar.date(byAdding: .month, value: -(Self.retainedMonths - 1), to: now()) else { return }
        let threshold = Self.monthKey(for: oldest)
        for url in files() {
            guard let key = Self.monthKey(ofFileName: url.lastPathComponent), key < threshold else { continue }
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                logger.error("No se pudo borrar \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func fileURL(for date: Date) -> URL {
        directory.appending(path: "capture-\(Self.monthKey(for: date)).jsonl")
    }

    /// `YYYY-MM` en Panamá.
    static func monthKey(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = CaptureLogCoding.panama
        let components = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }

    /// `capture-2026-10.jsonl` → `2026-10`; cualquier otro nombre → `nil`.
    static func monthKey(ofFileName name: String) -> String? {
        guard name.hasPrefix("capture-"), name.hasSuffix(".jsonl") else { return nil }
        let key = name.dropFirst("capture-".count).dropLast(".jsonl".count)
        guard key.count == 7, key.dropFirst(4).first == "-",
              key.allSatisfy({ $0.isNumber || $0 == "-" }) else { return nil }
        return String(key)
    }
}
