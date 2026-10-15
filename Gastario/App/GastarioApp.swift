import GastarioCore
import OSLog
import SwiftData
import SwiftUI

@main
struct GastarioApp: App {
    private let container: ModelContainer

    init() {
        container = GastarioStore.makeContainer(inMemory: false)
        // Gate de la Fase 0: confirma que el store está en el App Group.
        Logger.app.info("Store: \(GastarioStore.storeURL().path(percentEncoded: false), privacy: .public)")
    }

    var body: some Scene {
        WindowGroup {
            MovementListView()
        }
        .modelContainer(container)
    }
}

extension Logger {
    static let app = Logger(subsystem: "com.renandiaz.Gastario", category: "app")
}
