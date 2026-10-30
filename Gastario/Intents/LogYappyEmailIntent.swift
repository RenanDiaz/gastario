import AppIntents
import CryptoKit
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
        let body = content ?? ""
        // Bitácora (Fase 7a): lo primero, antes de tocar el store. Solo largo y hash: el correo
        // sigue en Mail. Un Content incompleto (sin cuerpo) se ve en el largo.
        let log = SharedCaptureLog.log
        let invocation = UUID()
        let hash = SHA256.hash(data: Data(body.utf8)).map { String(format: "%02x", $0) }.joined()
        log.record(.receivedYappy(invocation, contentLength: body.count, contentSHA256: hash))

        do {
            // Solo lanza si el store no responde: un fallo de parseo se guarda igual (principio 1).
            let outcome = try await SharedModelContainer
                .captureService(observer: CaptureLogObserver(log: log, invocation: invocation))
                .captureYappy(content: body)
            Logger.app.info("Yappy capturado: \(String(describing: outcome), privacy: .public)")
        } catch {
            log.record(.error(invocation, error))
            throw error
        }
        log.record(.done(invocation))
        return .result()
    }
}
