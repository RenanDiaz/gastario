import GastarioCore
import OSLog
import SwiftData
import UserNotifications

/// Identificadores fuera de cualquier actor: los usa el delegate `nonisolated`.
enum NotificationIDs {
    static let category = "MOVEMENT_QUESTION"
    static let replyAction = "REPLY"
}

/// Paso 5 del pipeline de captura: notificación local inmediata con respuesta de texto
/// (`INTENT.md`, Notificaciones). Reemplaza al no-op de la Fase 2.
@MainActor
final class NotificationService: MovementNotifier {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    /// "Responder" **sin** `.foreground`: la respuesta se guarda sin abrir la app.
    static var category: UNNotificationCategory {
        let reply = UNTextInputNotificationAction(
            identifier: NotificationIDs.replyAction, title: "Responder", options: [],
            textInputButtonTitle: "Guardar", textInputPlaceholder: "¿En qué fue?")
        return UNNotificationCategory(
            identifier: NotificationIDs.category, actions: [reply], intentIdentifiers: [], options: [])
    }

    /// Versiones `async` desde contextos `nonisolated`: un completion handler creado en el
    /// `MainActor` y llamado por el sistema desde otro hilo falla la verificación de
    /// aislamiento de Swift 6.
    nonisolated static func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            Logger.app.info("Permiso de notificaciones: \(granted, privacy: .public)")
        } catch {
            Logger.app.error("Permiso de notificaciones: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Nunca lanza: una notificación que no sale no debe afectar la captura.
    func notify(movementID: UUID) async {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Movement>(predicate: #Predicate { $0.id == movementID })
        descriptor.fetchLimit = 1
        guard let movement = try? context.fetch(descriptor).first else {
            Logger.app.error("No se encontró el movimiento a notificar: \(movementID, privacy: .public)")
            return
        }

        let text = NotificationText.build(for: movement)
        // El identificador es el del movimiento: así la respuesta sabe a cuál pertenece.
        await Self.schedule(id: movementID.uuidString, text: text)
    }

    private nonisolated static func schedule(id: String, text: NotificationText) async {
        let content = UNMutableNotificationContent()
        content.title = text.title
        content.body = text.body
        content.sound = .default
        content.categoryIdentifier = NotificationIDs.category
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            Logger.app.error("No se pudo programar la notificación: \(error.localizedDescription, privacy: .public)")
        }
    }
}
