import Foundation

extension CaptureLogEvent {
    /// Se escribe antes de borrar: después el movimiento ya no se puede leer.
    public static func deleted(_ movement: Movement, from origin: DeletionOrigin) -> Self {
        var event = Self(ev: .deleted)
        event.movementID = movement.id
        event.src = movement.sourceRaw
        event.amount = "\(movement.amount)"
        event.counterparty = movement.counterparty
        event.capturedAt = movement.capturedAt
        event.from = origin
        return event
    }
}
