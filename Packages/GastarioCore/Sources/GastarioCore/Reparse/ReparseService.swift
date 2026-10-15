import Foundation
import GastarioParsing
import SwiftData

/// Vuelve a correr el parser sobre el crudo guardado (`INTENT.md`, Re-parseo). Así una mejora
/// del parser corrige el histórico sin recapturar nada (principio 2).
///
/// Nunca toca `note`, `notedAt`, `attachments` ni los campos de `editedFields` (lo garantiza
/// `ParseApplier`). Los movimientos `manual` no tienen crudo y se ignoran.
@MainActor
public struct ReparseService {
    private let parser: any CaptureParser

    public init(parser: any CaptureParser = DefaultCaptureParser()) {
        self.parser = parser
    }

    /// Re-parsea un movimiento en cualquier estado. Devuelve `true` si algo cambió. No guarda:
    /// lo hace quien llama.
    @discardableResult
    public func reparse(_ movement: Movement) -> Bool {
        let before = Snapshot(movement)
        switch movement.source {
        case .manual:
            return false
        case .card:
            guard
                let json = movement.rawInputs?.data(using: .utf8),
                let inputs = try? JSONDecoder().decode(CardRawInputs.self, from: json),
                let parsed = try? parser.parseCard(inputs)
            else { return false }
            ParseApplier.apply(parsed, to: movement)
        case .yappy:
            guard let content = movement.rawContent, let parsed = try? parser.parseYappy(content) else {
                return false
            }
            ParseApplier.apply(parsed, to: movement)
        }
        return Snapshot(movement) != before
    }

    /// "Re-parsear todo": solo movimientos con `parseStatus != ok` y que no sean `manual`.
    /// Guarda y devuelve cuántos cambiaron.
    public func reparseAll(in context: ModelContext) throws -> Int {
        let ok = ParseStatus.ok.rawValue
        let manual = Source.manual.rawValue
        let pending = try context.fetch(FetchDescriptor<Movement>(
            predicate: #Predicate { $0.parseStatusRaw != ok && $0.sourceRaw != manual }))
        let changed = pending.filter { reparse($0) }.count
        try context.save()
        return changed
    }

    /// Lo que el parser puede cambiar; sirve para contar movimientos actualizados.
    private struct Snapshot: Equatable {
        let amount: Decimal
        let direction: String
        let counterparty: String?
        let occurredAt: Date
        let status: String
        let issues: [String]
        let confirmation: String?
        let message: String?
        let cardName: String?
        let city: String?

        init(_ movement: Movement) {
            amount = movement.amount
            direction = movement.directionRaw
            counterparty = movement.counterparty
            occurredAt = movement.occurredAt
            status = movement.parseStatusRaw
            issues = movement.parseIssuesRaw
            confirmation = movement.confirmation
            message = movement.yappyMessage
            cardName = movement.cardName
            city = movement.city
        }
    }
}
