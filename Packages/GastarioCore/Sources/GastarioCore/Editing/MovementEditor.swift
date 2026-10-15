import Foundation
import GastarioParsing

/// Ediciones a mano desde el detalle (SPEC Fase 4). Cada edición de monto, contraparte o fecha:
/// - agrega el campo a `editedFields`, así el re-parseo no lo pisa;
/// - quita su `ParseIssue`;
/// - si el movimiento era `partial` y ya no quedan issues, pasa a `ok` (AC-13).
///
/// Un `failed` **no** cambia de estado por edición: su crudo no se entendió y editar a mano no
/// lo valida. Solo el re-parseo lo resuelve. Nada se guarda aquí: lo hace quien llama.
public enum MovementEditor {
    /// Ignora montos no positivos: no resuelven el issue `amount`.
    public static func setAmount(_ amount: Decimal, on movement: Movement) {
        guard amount > 0 else { return }
        movement.amount = amount
        markEdited(.amount, resolving: .amount, on: movement)
    }

    /// Ignora una contraparte vacía.
    public static func setCounterparty(_ counterparty: String, on movement: Movement) {
        let trimmed = counterparty.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        movement.counterparty = trimmed
        markEdited(.counterparty, resolving: .counterparty, on: movement)
    }

    public static func setOccurredAt(_ date: Date, on movement: Movement) {
        movement.occurredAt = date
        markEdited(.occurredAt, resolving: .occurredAt, on: movement)
    }

    /// Una nota vacía la borra. `notedAt` se asigna la primera vez y se conserva en ediciones
    /// posteriores.
    public static func setNote(_ note: String, on movement: Movement, at date: Date = .now) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            movement.note = nil
            movement.notedAt = nil
        } else {
            movement.note = trimmed
            if movement.notedAt == nil { movement.notedAt = date }
        }
    }

    private static func markEdited(_ field: EditableField, resolving issue: ParseIssue, on movement: Movement) {
        movement.editedFields.insert(field)
        var issues = movement.parseIssues
        issues.remove(issue)
        movement.parseIssues = issues
        if movement.parseStatus == .partial && issues.isEmpty {
            movement.parseStatus = .ok
        }
    }
}

extension Movement {
    /// Entrada manual (AC-14): `source = manual`, `parseStatus = ok`. No pasa por
    /// `CaptureService`, así que no notifica.
    public static func manual(
        amount: Decimal, direction: Direction, counterparty: String?, occurredAt: Date,
        note: String?, at date: Date = .now
    ) -> Movement {
        let trimmed = counterparty?.trimmingCharacters(in: .whitespacesAndNewlines)
        let movement = Movement(
            source: .manual, direction: direction, amount: amount,
            counterparty: (trimmed?.isEmpty ?? true) ? nil : trimmed,
            occurredAt: occurredAt, capturedAt: date)
        if let note { MovementEditor.setNote(note, on: movement, at: date) }
        return movement
    }
}
