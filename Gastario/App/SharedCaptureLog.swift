import Foundation
import GastarioCore

/// Una sola bitácora de captura por proceso (SPEC Fase 7a). Aparte de `SharedModelContainer` a
/// propósito: el intent escribe `received` antes de tocar el store, y abrir el store es uno de
/// los pasos que la bitácora tiene que poder ver fallar.
@MainActor
enum SharedCaptureLog {
    static let log: CaptureLog = {
        let info = Bundle.main.infoDictionary
        return CaptureLog(
            directory: directory,
            version: info?["CFBundleShortVersionString"] as? String ?? "?",
            build: info?["CFBundleVersion"] as? String ?? "?")
    }()

    /// `<App Group>/Logs`. Sin App Group la app ni siquiera abre el store (`GastarioStore`), pero
    /// la bitácora no debe ser la que truene: cae al directorio temporal.
    private static var directory: URL {
        let base = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: GastarioStore.appGroupIdentifier
        ) ?? FileManager.default.temporaryDirectory
        return base.appending(path: "Logs", directoryHint: .isDirectory)
    }
}
