import Foundation
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

    /// `UserDefaults` del App Group: estado del respaldo (SPEC §2, C4).
    static let defaults = UserDefaults(suiteName: GastarioStore.appGroupIdentifier) ?? .standard

    /// Un solo servicio de respaldo por proceso: la app, los intents y Ajustes comparten estado.
    static let backup = BackupService(container: container, state: BackupState(defaults: defaults))

    /// El pipeline de captura de los intents: notificaciones (Fase 3) y auto-export (Fase 5).
    /// `observer` escribe los pasos en la bitácora de captura (Fase 7a).
    static func captureService(observer: any CaptureObserver) -> CaptureService {
        CaptureService(
            container: container, notifier: NotificationService(container: container), backup: backup,
            observer: observer)
    }
}
