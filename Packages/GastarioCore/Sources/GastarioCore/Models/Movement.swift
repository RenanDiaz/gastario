import Foundation
import GastarioParsing
import SwiftData

/// Un movimiento de dinero. Se llama `Movement` y no `Transaction` para no chocar con
/// `SwiftUI.Transaction` (`INTENT.md`).
///
/// Los enums y los conjuntos se persisten como `String` / `[String]` con accesores tipados
/// (SPEC §3, "Enums persistidos con String raw value"): los predicados de SwiftData sobre
/// enums Codable no son confiables, y los filtros de la Fase 4 necesitan `parseStatusRaw`.
@Model
public final class Movement {
    public var id: UUID
    public var sourceRaw: String
    public var directionRaw: String
    /// Siempre positivo; el signo lo da `direction`.
    public var amount: Decimal
    public var counterparty: String?
    public var cardName: String?
    public var yappyMessage: String?
    /// Junto con `direction`, clave de deduplicación de Yappy (SPEC §2, C11). Sin `.unique`:
    /// haría upsert y pisaría la `note` del registro existente.
    public var confirmation: String?
    public var occurredAt: Date
    public var capturedAt: Date
    public var city: String?
    public var latitude: Double?
    public var longitude: Double?
    public var rawContent: String?
    public var rawInputs: String?
    public var parseStatusRaw: String
    public var parseIssuesRaw: [String]
    public var editedFieldsRaw: [String]
    public var note: String?
    public var notedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \Attachment.movement)
    public var attachments: [Attachment] = []

    public init(
        id: UUID = UUID(),
        source: Source,
        direction: Direction,
        amount: Decimal,
        counterparty: String? = nil,
        occurredAt: Date,
        capturedAt: Date = .now,
        parseStatus: ParseStatus = .ok,
        parseIssues: Set<ParseIssue> = []
    ) {
        self.id = id
        self.sourceRaw = source.rawValue
        self.directionRaw = direction.rawValue
        self.amount = amount
        self.counterparty = counterparty
        self.occurredAt = occurredAt
        self.capturedAt = capturedAt
        self.parseStatusRaw = parseStatus.rawValue
        self.parseIssuesRaw = parseIssues.map(\.rawValue).sorted()
        self.editedFieldsRaw = []
    }

    // Un valor crudo desconocido solo puede venir de un bug o de datos corruptos. Se lee con el
    // valor más conservador en vez de fallar: `failed` lo deja visible en "Requiere revisión".

    public var source: Source {
        get { Source(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    public var direction: Direction {
        get { Direction(rawValue: directionRaw) ?? .outflow }
        set { directionRaw = newValue.rawValue }
    }

    public var parseStatus: ParseStatus {
        get { ParseStatus(rawValue: parseStatusRaw) ?? .failed }
        set { parseStatusRaw = newValue.rawValue }
    }

    public var parseIssues: Set<ParseIssue> {
        get { Set(parseIssuesRaw.compactMap(ParseIssue.init(rawValue:))) }
        set { parseIssuesRaw = newValue.map(\.rawValue).sorted() }
    }

    public var editedFields: Set<EditableField> {
        get { Set(editedFieldsRaw.compactMap(EditableField.init(rawValue:))) }
        set { editedFieldsRaw = newValue.map(\.rawValue).sorted() }
    }

    public var needsReview: Bool { parseStatus != .ok }
    public var hasNote: Bool { !(note?.isEmpty ?? true) }
}
