import GastarioCore
import OSLog
import UIKit
import UserNotifications

/// Al responder una notificación con la app terminada, iOS lanza el proceso y llama a
/// `didReceive` sin que exista ninguna vista. Por eso el delegate y el container se preparan
/// aquí y no en una escena SwiftUI (`INTENT.md`, Notificaciones).
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Síncrono, antes de que pueda llegar una respuesta (SPEC Fase 3, Riesgos).
        _ = SharedModelContainer.container

        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories([NotificationService.category])
        Task { await NotificationService.requestAuthorization() }
        return true
    }

    // `nonisolated`: compila igual si el SDK marca el protocolo como `@MainActor` o no. Solo
    // valores `Sendable` cruzan al `MainActor`.

    /// "Responder" guarda la nota sin abrir la app; el sistema da por terminada la respuesta
    /// cuando se llama `completionHandler`, con la nota ya guardada (`INTENT.md`, el completion va
    /// después del save). Tocar la notificación abre el detalle del movimiento (C15).
    ///
    /// Forma con completion handler y no `async`: con la variante `async`, el thunk que genera el
    /// compilador llama al completion desde el executor genérico (un hilo secundario), y para la
    /// acción por defecto UIKit responde con `-[UIApplication _updateSnapshotAndStateRestoration
    /// WithAction:windowScene:]`, que exige el hilo principal: `NSInternalInconsistencyException`
    /// "Call must be made on main thread" y la app muere con SIGABRT al abrirse. Aquí el
    /// completion se llama desde el `MainActor`.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        let movementID = UUID(uuidString: response.notification.request.identifier)
        let action = response.actionIdentifier
        let text = (response as? UNTextInputNotificationResponse)?.userText
        Task { @MainActor in
            defer { completionHandler() }
            guard let movementID else { return }
            switch action {
            case NotificationIDs.replyAction:
                guard let text else { return }
                await saveReply(movementID: movementID, text: text)
            case UNNotificationDefaultActionIdentifier:
                openMovement(movementID)
            default:
                return
            }
        }
    }

    /// Con la app abierta, la notificación se muestra igual.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    @MainActor
    private func openMovement(_ movementID: UUID) {
        Logger.app.info("Notificación tocada: \(movementID, privacy: .public)")
        NotificationRouter.shared.movementToOpen = movementID
    }

    @MainActor
    private func saveReply(movementID: UUID, text: String) async {
        let saved = await NoteReplyHandler(container: SharedModelContainer.container)
            .handle(movementID: movementID, text: text)
        Logger.app.info("Respuesta guardada: \(saved, privacy: .public)")
    }
}
