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

    /// El sistema da por terminada la respuesta cuando este método retorna: la nota ya está
    /// guardada (`INTENT.md`, el completion va después del save).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        guard
            response.actionIdentifier == NotificationIDs.replyAction,
            let text = (response as? UNTextInputNotificationResponse)?.userText,
            let movementID = UUID(uuidString: response.notification.request.identifier)
        else { return }
        await saveReply(movementID: movementID, text: text)
    }

    /// Con la app abierta, la notificación se muestra igual.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    @MainActor
    private func saveReply(movementID: UUID, text: String) async {
        let saved = await NoteReplyHandler(container: SharedModelContainer.container)
            .handle(movementID: movementID, text: text)
        Logger.app.info("Respuesta guardada: \(saved, privacy: .public)")
    }
}
