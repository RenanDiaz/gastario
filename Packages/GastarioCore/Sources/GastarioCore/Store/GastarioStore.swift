import Foundation
import SwiftData

public enum GastarioStore {
    public static let appGroupIdentifier = "group.com.renandiaz.Gastario"

    public static var schema: Schema { Schema([Movement.self, Attachment.self]) }

    /// En disco, el store vive en el container del App Group desde el primer día: moverlo después
    /// sería una migración de datos (`INTENT.md`, Persistencia).
    ///
    /// Si el App Group no está disponible falla en voz alta: es un error de configuración
    /// (capability o entitlements), no algo que se resuelva en runtime.
    public static func makeContainer(inMemory: Bool) -> ModelContainer {
        let configuration = inMemory
            // Nombre único: cada container en memoria queda aislado (pruebas en paralelo).
            ? ModelConfiguration(
                UUID().uuidString, schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            // Sin CloudKit explícito: `.automatic` lo activaría si la app gana una capability de
            // iCloud (Fase 5), y la sincronización está fuera de alcance (`INTENT.md`).
            : ModelConfiguration(schema: schema, url: storeURL(), cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("No se pudo abrir el store de SwiftData: \(error)")
        }
    }

    /// `<App Group>/Library/Application Support/Gastario.store`.
    public static func storeURL() -> URL {
        guard let group = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            fatalError("El App Group \(appGroupIdentifier) no está disponible: revisa la capability App Groups en project.yml y la firma.")
        }
        let directory = group.appending(path: "Library/Application Support", directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            fatalError("No se pudo crear \(directory.path(percentEncoded: false)): \(error)")
        }
        return directory.appending(path: "Gastario.store")
    }
}
