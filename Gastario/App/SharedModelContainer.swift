import GastarioCore
import OSLog
import SwiftData

/// Un solo `ModelContainer` por proceso, compartido por la app y los App Intents. Un intent en
/// segundo plano puede correr sin que exista ninguna escena.
@MainActor
enum SharedModelContainer {
    static let container: ModelContainer = {
        let container = GastarioStore.makeContainer(inMemory: false)
        // Gate de la Fase 0: confirma que el store está en el App Group.
        Logger.app.info("Store: \(GastarioStore.storeURL().path(percentEncoded: false), privacy: .public)")
        return container
    }()

    /// El pipeline de captura de los intents, con las notificaciones de la Fase 3.
    static func captureService() -> CaptureService {
        CaptureService(container: container, notifier: NotificationService(container: container))
    }
}
