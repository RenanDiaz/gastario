import Foundation
import GastarioCore
import OSLog
import SwiftData

enum BackupError: LocalizedError {
    case iCloudUnavailable

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable: "iCloud Drive no está disponible."
        }
    }
}

/// Paso 6 del pipeline de captura: si pasaron 7+ días, escribe el CSV completo en
/// iCloud Drive → Gastario (`INTENT.md`, Respaldo). Reemplaza el no-op de la Fase 2.
///
/// Un fallo nunca llega a la captura: `runIfDue` no lanza; el error queda en `BackupState` y se
/// reintenta en la siguiente ejecución.
@MainActor
final class BackupService: BackupTrigger {
    private let container: ModelContainer
    let state: BackupState

    init(container: ModelContainer, state: BackupState) {
        self.container = container
        self.state = state
    }

    struct ExportResult {
        /// Copia local para compartir; existe aunque iCloud falle.
        let localURL: URL?
        let error: String?
    }

    func runIfDue() async {
        guard state.isDue(now: .now) else { return }
        await export()
    }

    /// Exporta ya ("Exportar ahora" o auto-export).
    @discardableResult
    func export(now: Date = .now) async -> ExportResult {
        let rows: [CSVRow]
        do {
            rows = try ModelContext(container).fetch(FetchDescriptor<Movement>()).map { CSVRow($0) }
        } catch {
            return fail(error.localizedDescription, at: now, localURL: nil)
        }
        let data = CSVExporter.export(rows)
        let name = BackupPolicy.fileName(for: now)
        let localURL = try? Self.writeLocalCopy(data, name: name)

        do {
            try await Self.writeToICloud(data, name: name)
            state.recordSuccess(at: now)
            Logger.app.info("Respaldo escrito en iCloud: \(name, privacy: .public)")
            return ExportResult(localURL: localURL, error: nil)
        } catch {
            return fail(error.localizedDescription, at: now, localURL: localURL)
        }
    }

    private func fail(_ message: String, at date: Date, localURL: URL?) -> ExportResult {
        state.recordFailure(message, at: date)
        Logger.app.error("Respaldo falló: \(message, privacy: .public)")
        return ExportResult(localURL: localURL, error: message)
    }

    /// `url(forUbiquityContainerIdentifier:)` puede bloquear: corre fuera del main actor.
    @concurrent
    private nonisolated static func writeToICloud(_ data: Data, name: String) async throws {
        let fileManager = FileManager.default
        guard let container = fileManager.url(forUbiquityContainerIdentifier: nil) else {
            throw BackupError.iCloudUnavailable
        }
        let documents = container.appending(path: "Documents", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: documents, withIntermediateDirectories: true)
        try data.write(to: documents.appending(path: name), options: .atomic)
    }

    private static func writeLocalCopy(_ data: Data, name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: name)
        try data.write(to: url, options: .atomic)
        return url
    }
}
