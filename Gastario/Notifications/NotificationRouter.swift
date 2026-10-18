import Foundation
import Observation

/// Tocar una notificación abre el detalle del movimiento con la nota lista para escribir (C15).
/// El delegate deja aquí el ID; la lista navega y el detalle abre el editor.
@MainActor @Observable
final class NotificationRouter {
    static let shared = NotificationRouter()

    /// Lo pone el delegate y lo limpia `MovementListView` al navegar. Puede llegar antes de que
    /// exista la vista (arranque en frío desde la notificación).
    var movementToOpen: UUID?
    /// Lo limpia `MovementDetailView` al abrir el editor con la nota enfocada.
    var noteToEdit: UUID?
}
