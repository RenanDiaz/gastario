import GastarioCore
import OSLog
import SwiftData
import SwiftUI

@main
struct GastarioApp: App {
    var body: some Scene {
        WindowGroup {
            MovementListView()
        }
        .modelContainer(SharedModelContainer.container)
    }
}

extension Logger {
    static let app = Logger(subsystem: "com.renandiaz.Gastario", category: "app")
}
