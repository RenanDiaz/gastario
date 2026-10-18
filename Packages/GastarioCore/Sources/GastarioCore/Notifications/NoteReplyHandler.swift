import Foundation
import OSLog
import SwiftData

/// Guarda la respuesta de la notificación en `note` (AC-8). La llama el delegate de
/// notificaciones, también con la app lanzada solo para recibir la respuesta.
@MainActor
public struct NoteReplyHandler {
    private let container: ModelContainer
    private let logger = Logger(subsystem: "com.renandiaz.Gastario", category: "notifications")

    public init(container: ModelContainer) {
        self.container = container
    }

    /// `true` si guardó la nota. Nunca lanza: un ID inexistente (movimiento borrado) o una
    /// respuesta vacía se ignoran.
    @discardableResult
    public func handle(movementID: UUID, text: String, at date: Date = .now) async -> Bool {
        let note = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else { return false }

        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Movement>(predicate: #Predicate { $0.id == movementID })
        descriptor.fetchLimit = 1
        do {
            guard let movement = try context.fetch(descriptor).first else {
                logger.info("Respuesta para un movimiento que ya no existe: \(movementID, privacy: .public)")
                return false
            }
            movement.note = note
            movement.notedAt = date
            try context.save()
            return true
        } catch {
            logger.error("No se pudo guardar la nota: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
