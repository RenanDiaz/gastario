import Foundation

/// Comparación del período en paralelo (SPEC, Fase 7, pasos 2 y 3).
///
/// Además de los conteos y sumas por día, empareja fila por fila para que cada discrepancia
/// tenga nombre y línea:
/// - **Yappy** por confirmación, que es única por correo. Las filas sin confirmación
///   (un `failed` en Gastario) se intentan por día y monto.
/// - **Tarjeta** por monto y hora del atajo: el `Append` corre justo antes del intent, así que
///   las dos filas quedan a segundos. El CSV viejo guarda solo hasta el minuto.
public struct Comparison: Sendable {
    public struct DayTotals: Sendable, Equatable {
        public var count = 0
        public var sum: Decimal = 0

        mutating func add(_ record: Record) {
            count += 1
            sum += record.amount
        }
    }

    public struct DayRow: Sendable, Equatable {
        public var day: String
        public var old: [Source: DayTotals] = [:]
        public var gastario: [Source: DayTotals] = [:]

        public var matches: Bool {
            Source.allCases.allSatisfy { old[$0, default: .init()] == gastario[$0, default: .init()] }
        }
    }

    public enum Kind: String, Sendable {
        case onlyOld = "Solo en el CSV viejo"
        case onlyGastario = "Solo en Gastario"
        case amountDiffers = "Monto distinto"
        case duplicateOld = "Repetida en el CSV viejo"
    }

    public struct Discrepancy: Sendable, Equatable {
        public var kind: Kind
        public var record: Record
        /// La fila del otro lado, cuando se emparejaron pero no coinciden.
        public var other: Record?
        /// Clase probable de la SPEC (a)–(d). La decide la persona; esto es solo una pista.
        public var hint: String
    }

    public var from: String
    public var to: String
    public var days: [DayRow]
    public var discrepancies: [Discrepancy]
    public var invalidOldRows: [InvalidRow]

    /// Tolerancia entre la hora del CSV viejo de tarjeta (al minuto) y `capturedAt` de Gastario.
    static let cardWindow: TimeInterval = 5 * 60

    /// - Parameters:
    ///   - from, to: días `yyyy-MM-dd` incluidos. Sin `from`, el primer día con capturas en
    ///     Gastario (antes no corría en paralelo); sin `to`, el último.
    public init(
        gastario: [Record], oldCard: [Record], oldYappy: [Record], invalidOldYappy: [InvalidRow] = [],
        from: String? = nil, to: String? = nil
    ) throws {
        let gastarioDays = gastario.map(\.day).sorted()
        guard let first = from ?? gastarioDays.first, let last = to ?? gastarioDays.last else {
            throw ReportError.invalidArguments("El export de Gastario no tiene capturas de tarjeta ni de Yappy; indica --desde y --hasta.")
        }
        self.from = first
        self.to = last
        let inRange = { (record: Record) in record.day >= first && record.day <= last }

        let gastario = gastario.filter(inRange)
        let oldCard = oldCard.filter(inRange)
        let oldYappy = oldYappy.filter(inRange)
        invalidOldRows = invalidOldYappy.filter { $0.day >= first && $0.day <= last }

        // Una confirmación repetida en el CSV viejo es el atajo corriendo dos veces sobre el mismo
        // correo, no otro movimiento: cuenta una vez (Gastario deduplica igual) y se lista aparte.
        var seen: Set<String> = []
        let uniqueOldYappy = oldYappy.filter { record in
            record.confirmation.map { seen.insert($0).inserted } ?? true
        }

        var byDay: [String: DayRow] = [:]
        for record in oldCard + uniqueOldYappy {
            byDay[record.day, default: DayRow(day: record.day)].old[record.source, default: .init()].add(record)
        }
        for record in gastario {
            byDay[record.day, default: DayRow(day: record.day)].gastario[record.source, default: .init()].add(record)
        }
        days = byDay.values.sorted { $0.day < $1.day }

        discrepancies = Self.matchYappy(old: oldYappy, gastario: gastario.filter { $0.source == .yappy })
            + Self.matchCard(old: oldCard, gastario: gastario.filter { $0.source == .card })
        discrepancies.sort { $0.record.occurredAt < $1.record.occurredAt }
    }

    static func matchYappy(old: [Record], gastario: [Record]) -> [Discrepancy] {
        var result: [Discrepancy] = []
        var remaining = gastario
        var unmatchedOld: [Record] = []
        var seen: Set<String> = []

        for record in old {
            guard let confirmation = record.confirmation else {
                unmatchedOld.append(record)
                continue
            }
            guard seen.insert(confirmation).inserted else {
                result.append(Discrepancy(
                    kind: .duplicateOld, record: record, other: nil,
                    hint: "El atajo viejo corrió dos veces sobre el mismo correo; no es una captura"))
                continue
            }
            if let index = remaining.firstIndex(where: { $0.confirmation == confirmation }) {
                let match = remaining.remove(at: index)
                if match.amount != record.amount {
                    result.append(Discrepancy(
                        kind: .amountDiffers, record: record, other: match,
                        hint: "Revisar cuál leyó bien el correo"))
                }
            } else {
                unmatchedOld.append(record)
            }
        }

        // Sin confirmación de un lado: por día y monto exacto.
        for record in unmatchedOld {
            if let index = remaining.firstIndex(where: {
                ($0.confirmation == nil || record.confirmation == nil) && $0.day == record.day && $0.amount == record.amount
            }) {
                remaining.remove(at: index)
            } else {
                result.append(Discrepancy(
                    kind: .onlyOld, record: record, other: nil,
                    hint: "(c) captura perdida en Gastario, salvo que no sea un Yappy"))
            }
        }
        for record in remaining {
            let hint: String
            if record.parseStatus == "failed" {
                hint = "`failed`: probablemente un correo que no es de Yappy; bórralo en Gastario"
            } else if record.confirmation != nil {
                hint = "(d) captura perdida en el CSV viejo"
            } else {
                hint = "(a) posible duplicado sin confirmación (C3)"
            }
            result.append(Discrepancy(kind: .onlyGastario, record: record, other: nil, hint: hint))
        }
        return result
    }

    static func matchCard(old: [Record], gastario: [Record]) -> [Discrepancy] {
        var result: [Discrepancy] = []
        var remaining = gastario
        for record in old {
            let candidates = remaining.indices.filter {
                remaining[$0].amount == record.amount
                    && abs(remaining[$0].capturedAt.timeIntervalSince(record.capturedAt)) <= cardWindow
            }
            if let index = candidates.min(by: {
                abs(remaining[$0].capturedAt.timeIntervalSince(record.capturedAt))
                    < abs(remaining[$1].capturedAt.timeIntervalSince(record.capturedAt))
            }) {
                remaining.remove(at: index)
                continue
            }
            // Misma hora y otro monto: Gastario no leyó el monto (`partial`) o lo editaste.
            if let index = remaining.firstIndex(where: {
                abs($0.capturedAt.timeIntervalSince(record.capturedAt)) <= cardWindow
            }) {
                let match = remaining.remove(at: index)
                result.append(Discrepancy(
                    kind: .amountDiffers, record: record, other: match,
                    hint: match.amount == 0 ? "`partial` sin monto en Gastario; complétalo" : "¿Editado en Gastario?"))
            } else {
                result.append(Discrepancy(
                    kind: .onlyOld, record: record, other: nil, hint: "(c) captura perdida en Gastario"))
            }
        }
        for record in remaining {
            result.append(Discrepancy(
                kind: .onlyGastario, record: record, other: nil,
                hint: "(d) captura perdida en el CSV viejo, o (a) duplicado"))
        }
        return result
    }
}
