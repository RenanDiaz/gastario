import Foundation
import GastarioParsing

public enum Source: String, Sendable, CaseIterable {
    case card = "Tarjeta"
    case yappy = "Yappy"
}

/// Un movimiento leído de cualquiera de los tres CSVs, con el monto con signo (salida negativa).
public struct Record: Sendable, Equatable {
    public var source: Source
    /// Fecha del movimiento: la de Yappy para correos, la del tap para tarjeta.
    public var occurredAt: Date
    /// Cuándo corrió el atajo. Para tarjeta es lo que se compara.
    public var capturedAt: Date
    public var amount: Decimal
    public var counterparty: String
    public var confirmation: String?
    /// `parseStatus` de Gastario; `nil` en los CSVs viejos.
    public var parseStatus: String?
    /// "archivo:línea", para encontrar la fila a mano.
    public var origin: String

    public var day: String { Day.key(occurredAt) }
}

/// Fila del CSV viejo de Yappy que no es un movimiento: sin tipo ni confirmación.
public struct InvalidRow: Sendable, Equatable {
    public var origin: String
    /// Día en que corrió el atajo, `yyyy-MM-dd`.
    public var day: String
    public var summary: String
}

enum Day {
    static let timeZone = YappyDateParser.timeZone

    static func key(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    /// `2026-10-03 11:34`, hora de Panamá (el `Formatted Date` de los atajos viejos).
    static func parseLocal(_ text: String) -> Date? {
        guard let match = text.wholeMatch(of: /(\d{4})-(\d{2})-(\d{2})[ T](\d{1,2}):(\d{2})(?::(\d{2}))?/)
        else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = DateComponents(
            year: Int(match.output.1), month: Int(match.output.2), day: Int(match.output.3),
            hour: Int(match.output.4), minute: Int(match.output.5),
            second: match.output.6.flatMap { Int($0) } ?? 0)
        return calendar.date(from: components)
    }

    static func parseISO(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }
}

/// Lectura de los tres archivos. Los nombres de columna son los de `CSVExporter` y los de los
/// `Text` de los atajos viejos (`fecha,comercio,monto,…` y `fecha,tipo,monto,…`).
public enum Loader {
    /// Export de Gastario. Los movimientos `manual` no vienen de un atajo: no se comparan.
    public static func gastario(_ text: String, file: String = "gastario") throws -> [Record] {
        let table = try CSVTable(
            text, file: file,
            requiredColumns: ["occurredAt", "capturedAt", "source", "amount", "counterparty", "confirmation", "parseStatus"])
        return try table.rows.compactMap { row in
            let source: Source
            switch row["source"] {
            case "card": source = .card
            case "yappy": source = .yappy
            default: return nil
            }
            guard let occurredAt = Day.parseISO(row["occurredAt"]) else {
                throw ReportError.invalidDate(file, line: row.line, value: row["occurredAt"])
            }
            guard let capturedAt = Day.parseISO(row["capturedAt"]) else {
                throw ReportError.invalidDate(file, line: row.line, value: row["capturedAt"])
            }
            return Record(
                source: source, occurredAt: occurredAt, capturedAt: capturedAt,
                amount: signed(row["amount"], outflow: row["amount"].hasPrefix("-")),
                counterparty: row["counterparty"], confirmation: confirmationKey(row["confirmation"]),
                parseStatus: row["parseStatus"], origin: "\(file):\(row.line)")
        }
    }

    /// CSV viejo de tarjeta: `fecha,comercio,monto,tarjeta,ciudad,lat,lon`. Todo es salida.
    public static func oldCard(_ text: String, file: String = "tarjeta") throws -> [Record] {
        let table = try CSVTable(text, file: file, requiredColumns: ["fecha", "comercio", "monto"])
        return try table.rows.map { row in
            guard let date = Day.parseLocal(row["fecha"]) else {
                throw ReportError.invalidDate(file, line: row.line, value: row["fecha"])
            }
            return Record(
                source: .card, occurredAt: date, capturedAt: date,
                amount: signed(row["monto"], outflow: true), counterparty: row["comercio"],
                confirmation: nil, parseStatus: nil, origin: "\(file):\(row.line)")
        }
    }

    /// CSV viejo de Yappy: `fecha,tipo,monto,contraparte,mensaje,confirmacion,fechaYappy`.
    ///
    /// - El signo sale de `tipo`: las primeras filas de "Enviaste" se escribieron sin `-`.
    /// - La fecha es `fechaYappy`; si no se pudo leer, la hora en que corrió el atajo.
    /// - Sin tipo ni confirmación no es un Yappy (un correo de otro remitente o uno que el
    ///   atajo viejo no pudo leer): va aparte, para revisarlo a mano.
    public static func oldYappy(_ text: String, file: String = "yappy") throws -> (records: [Record], invalid: [InvalidRow]) {
        let table = try CSVTable(text, file: file, requiredColumns: ["fecha", "tipo", "monto", "confirmacion"])
        var records: [Record] = []
        var invalid: [InvalidRow] = []
        for row in table.rows {
            guard let capturedAt = Day.parseLocal(row["fecha"]) else {
                throw ReportError.invalidDate(file, line: row.line, value: row["fecha"])
            }
            let kind = row["tipo"]
            let confirmation = confirmationKey(row["confirmacion"])
            guard !kind.isEmpty || confirmation != nil else {
                let fields = [row["fecha"], row["monto"], row["contraparte"], row["mensaje"]].filter { !$0.isEmpty }
                invalid.append(InvalidRow(
                    origin: "\(file):\(row.line)", day: Day.key(capturedAt), summary: fields.joined(separator: " · ")))
                continue
            }
            let outflow: Bool
            switch kind {
            case "Enviaste", "Pagaste": outflow = true
            case "Te enviaron": outflow = false
            default: outflow = row["monto"].hasPrefix("-")
            }
            records.append(Record(
                source: .yappy, occurredAt: YappyDateParser.parse(row["fechaYappy"]) ?? capturedAt,
                capturedAt: capturedAt, amount: signed(row["monto"], outflow: outflow),
                counterparty: row["contraparte"], confirmation: confirmation, parseStatus: nil,
                origin: "\(file):\(row.line)"))
        }
        return (records, invalid)
    }

    /// Monto con el signo pedido. Sin número (por ejemplo `-`) queda en 0, como en Gastario.
    static func signed(_ text: String, outflow: Bool) -> Decimal {
        let value = AmountParser.parse(text) ?? 0
        return outflow ? -value : value
    }

    static func confirmationKey(_ text: String) -> String? {
        text.isEmpty ? nil : text.uppercased()
    }
}
