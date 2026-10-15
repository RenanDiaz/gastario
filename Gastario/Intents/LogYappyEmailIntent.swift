import AppIntents
import GastarioCore
import OSLog

/// Lo llama el atajo del correo de notificaciones@yappy.com.pa (docs/shortcuts.md).
struct LogYappyEmailIntent: AppIntent {
    static var title: LocalizedStringResource { "Log Yappy Email" }
    static var description: IntentDescription { IntentDescription("Guarda un Yappy enviado o recibido en Gastario.") }
    /// Corre sin abrir la app.
    static var supportedModes: IntentModes { .background }

    /// Cuerpo del correo (`Content` en Atajos, en HTML). Opcional por la misma razón que en
    /// `LogCardMovementIntent`: nunca preguntar en segundo plano.
    @Parameter(title: "Content") var content: String?

    @MainActor
    func perform() async throws -> some IntentResult {
        // Diagnóstico: un Content incompleto (sin cuerpo) produce un movimiento sin confirmación.
        Logger.app.info("Yappy: Content con \(content?.count ?? 0) caracteres")
        // Solo lanza si el store no responde: un fallo de parseo se guarda igual (principio 1).
        let outcome = try await CaptureService(container: SharedModelContainer.container)
            .captureYappy(content: content ?? "")
        Logger.app.info("Yappy capturado: \(String(describing: outcome), privacy: .public)")
        return .result()
    }
}
