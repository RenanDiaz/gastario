import Foundation
import GastarioParsing

/// Una fila del CSV con valores simples: el exportador no depende de SwiftData y se prueba en
/// cualquier plataforma.
public struct CSVRow: Sendable, Equatable {
    public var occurredAt: Date
    public var capturedAt: Date
    public var source: String
    public var direction: Direction
    public var amount: Decimal
    public var counterparty: String?
    public var cardName: String?
    public var yappyMessage: String?
    public var confirmation: String?
    public var city: String?
    public var latitude: Double?
    public var longitude: Double?
    public var note: String?
    public var parseStatus: String
    public var attachmentCount: Int

    public init(
        occurredAt: Date, capturedAt: Date, source: String, direction: Direction, amount: Decimal,
        counterparty: String? = nil, cardName: String? = nil, yappyMessage: String? = nil,
        confirmation: String? = nil, city: String? = nil, latitude: Double? = nil, longitude: Double? = nil,
        note: String? = nil, parseStatus: String, attachmentCount: Int = 0
    ) {
        self.occurredAt = occurredAt
        self.capturedAt = capturedAt
        self.source = source
        self.direction = direction
        self.amount = amount
        self.counterparty = counterparty
        self.cardName = cardName
        self.yappyMessage = yappyMessage
        self.confirmation = confirmation
        self.city = city
        self.latitude = latitude
        self.longitude = longitude
        self.note = note
        self.parseStatus = parseStatus
        self.attachmentCount = attachmentCount
    }
}

/// CSV completo para respaldo y Numbers (`INTENT.md`, Exportar CSV; SPEC §2, C6):
/// - columnas exactas del INTENT, una fila por movimiento, ordenadas por `occurredAt`;
/// - montos con signo (`outflow` negativo) y dos decimales con punto;
/// - fechas ISO 8601 con offset de Panamá (`2026-10-04T08:31:00-05:00`);
/// - escape RFC 4180 y fin de línea CRLF; UTF-8 sin BOM.
public enum CSVExporter {
    public static let columns = [
        "occurredAt", "capturedAt", "source", "direction", "amount", "counterparty", "cardName",
        "yappyMessage", "confirmation", "city", "latitude", "longitude", "note", "parseStatus",
        "attachmentCount",
    ]

    public static func export(_ rows: [CSVRow]) -> Data {
        Data(csv(rows).utf8)
    }

    public static func csv(_ rows: [CSVRow]) -> String {
        let dates = ISO8601DateFormatter()
        dates.timeZone = TimeZone(identifier: "America/Panama")!
        dates.formatOptions = [.withInternetDateTime]

        var lines = [columns.joined(separator: ",")]
        for row in rows.sorted(by: { $0.occurredAt < $1.occurredAt }) {
            let fields: [String] = [
                dates.string(from: row.occurredAt),
                dates.string(from: row.capturedAt),
                row.source,
                row.direction.rawValue,
                signedAmount(row.amount, row.direction),
                row.counterparty ?? "",
                row.cardName ?? "",
                row.yappyMessage ?? "",
                row.confirmation ?? "",
                row.city ?? "",
                row.latitude.map { String($0) } ?? "",
                row.longitude.map { String($0) } ?? "",
                row.note ?? "",
                row.parseStatus,
                String(row.attachmentCount),
            ]
            lines.append(fields.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    static func signedAmount(_ amount: Decimal, _ direction: Direction) -> String {
        let value = direction == .outflow ? -amount : amount
        return value.formatted(
            .number.grouping(.never).precision(.fractionLength(2)).locale(Locale(identifier: "en_US_POSIX")))
    }

    /// RFC 4180: entre comillas si hay coma, comillas o salto de línea; las comillas se duplican.
    static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" || $0 == "\r\n" }) else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
