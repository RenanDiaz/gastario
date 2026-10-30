import GastarioCore
import OSLog
import SwiftData
import SwiftUI

@main
struct GastarioApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MovementListView()
        }
        .modelContainer(SharedModelContainer.container)
        // El auto-export se evalúa al final de cada intent **y** al abrir la app (`INTENT.md`).
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await SharedModelContainer.backup.runIfDue() }
                // Retención de la bitácora de captura (Fase 7a).
                SharedCaptureLog.log.prune()
            }
        }
    }
}

extension Logger {
    static let app = Logger(subsystem: "com.renandiaz.Gastario", category: "app")
}
