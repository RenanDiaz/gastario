import Foundation
import GastarioParsing

/// Vuelca el resultado de un parser sobre un `Movement`. Nunca toca `note`, `notedAt`,
/// `attachments` ni los campos de `editedFields` (`INTENT.md`, Re-parseo).
public enum ParseApplier {
    public static func apply(_ parsed: ParsedCard, to movement: Movement) {
        let edited = movement.editedFields
        movement.direction = .outflow
        if !edited.contains(.amount) { movement.amount = parsed.amount }
        if !edited.contains(.counterparty) { movement.counterparty = parsed.counterparty }
        if !edited.contains(.occurredAt) { movement.occurredAt = movement.capturedAt }
        movement.cardName = parsed.cardName
        movement.city = parsed.city
        movement.latitude = parsed.latitude
        movement.longitude = parsed.longitude
        setStatus(parsed.status, issues: parsed.issues, on: movement)
    }

    public static func apply(_ parsed: ParsedYappy, to movement: Movement) {
        let edited = movement.editedFields
        // Sin dirección el movimiento queda `failed` con el issue `direction`; `outflow` es solo
        // un valor de relleno, porque el modelo no admite dirección vacía.
        movement.direction = parsed.direction ?? .outflow
        if !edited.contains(.amount) { movement.amount = parsed.amount ?? 0 }
        if !edited.contains(.counterparty) { movement.counterparty = parsed.counterparty }
        if !edited.contains(.occurredAt) { movement.occurredAt = parsed.occurredAt ?? movement.capturedAt }
        movement.yappyMessage = parsed.message
        movement.confirmation = parsed.confirmation
        setStatus(parsed.status, issues: parsed.issues, on: movement)
    }

    /// Un campo editado a mano ya no es un issue (SPEC §2, C1).
    private static func setStatus(_ status: ParseStatus, issues: Set<ParseIssue>, on movement: Movement) {
        var remaining = issues
        for field in movement.editedFields {
            switch field {
            case .amount: remaining.remove(.amount)
            case .counterparty: remaining.remove(.counterparty)
            case .occurredAt: remaining.remove(.occurredAt)
            }
        }
        movement.parseIssues = remaining
        movement.parseStatus = status == .partial && remaining.isEmpty ? .ok : status
    }
}
