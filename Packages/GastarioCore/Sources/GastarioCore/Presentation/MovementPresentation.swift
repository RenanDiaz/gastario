import Foundation
import GastarioParsing

/// Filtros de la lista (SPEC Fase 4).
public enum MovementFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case noNote
    case needsReview

    public var id: Self { self }

    public var title: String {
        switch self {
        case .all: "Todos"
        case .noNote: "Sin nota"
        case .needsReview: "Revisar"
        }
    }

    /// "Sin nota" incluye también los manuales sin nota; "Revisar" es `parseStatus != ok`.
    public func matches(hasNote: Bool, status: ParseStatus) -> Bool {
        switch self {
        case .all: true
        case .noNote: !hasNote
        case .needsReview: status != .ok
        }
    }
}

/// Totales de un mes calendario en Panamá (SPEC §2, C9).
public struct MonthlySummary: Equatable, Sendable {
    public var outflow: Decimal
    public var inflow: Decimal
    public var net: Decimal { inflow - outflow }

    public init(outflow: Decimal = 0, inflow: Decimal = 0) {
        self.outflow = outflow
        self.inflow = inflow
    }
}

/// Movimientos de un mismo día calendario en Panamá.
public struct DayGroup<Item>: Identifiable {
    public let day: Date
    public let items: [Item]
    public var id: Date { day }
}

public enum MovementPresentation {
    public static let timeZone = TimeZone(identifier: "America/Panama")!

    /// Agrupa por día en `America/Panama` (nunca `.current`), días más recientes primero y,
    /// dentro de cada día, el orden de entrada.
    public static func groupedByDay<Item>(_ items: [Item], date: (Item) -> Date) -> [DayGroup<Item>] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var groups: [Date: [Item]] = [:]
        for item in items {
            groups[calendar.startOfDay(for: date(item)), default: []].append(item)
        }
        return groups
            .map { DayGroup(day: $0.key, items: $0.value) }
            .sorted { $0.day > $1.day }
    }

    /// Resumen del mes calendario que contiene `date`, en `America/Panama`. Incluye todos los
    /// `parseStatus` (C9).
    public static func monthlySummary<Item>(
        _ items: [Item], containing date: Date,
        amount: (Item) -> Decimal, direction: (Item) -> Direction, occurredAt: (Item) -> Date
    ) -> MonthlySummary {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let month = calendar.dateInterval(of: .month, for: date) else { return MonthlySummary() }
        var summary = MonthlySummary()
        // Semiabierto: el final del intervalo ya es el primer instante del mes siguiente.
        for item in items where occurredAt(item) >= month.start && occurredAt(item) < month.end {
            switch direction(item) {
            case .outflow: summary.outflow += amount(item)
            case .inflow: summary.inflow += amount(item)
            }
        }
        return summary
    }

    /// "octubre de 2026".
    public static func monthTitle(_ date: Date) -> String {
        var style = Date.FormatStyle().month(.wide).year()
        style.timeZone = timeZone
        return date.formatted(style.locale(Locale(identifier: "es_PA")))
    }

    /// Monto con signo: `-$3.80` para salidas, `+$600.00` para entradas. Un monto que no se pudo
    /// leer (issue `amount`, guardado como `0`) se muestra como `—` (SPEC §5, Q5).
    public static func amountText(amount: Decimal, direction: Direction, issues: Set<ParseIssue>) -> String {
        if issues.contains(.amount) && amount == 0 { return "—" }
        return (direction == .outflow ? "-" : "+") + currencyText(amount)
    }

    /// `$3.80`, `$1,250.00`: todo es USD (`INTENT.md`).
    public static func currencyText(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: "USD").locale(Locale(identifier: "en_US")))
    }

    public static func amountText(for movement: Movement) -> String {
        amountText(amount: movement.amount, direction: movement.direction, issues: movement.parseIssues)
    }

    /// Encabezado de sección, por ejemplo "miércoles, 7 de octubre de 2026".
    public static func dayTitle(_ day: Date) -> String {
        var style = Date.FormatStyle(date: .complete, time: .omitted)
        style.timeZone = timeZone
        return day.formatted(style.locale(Locale(identifier: "es_PA")))
    }

    /// Fecha y hora con segundos en Panamá, por ejemplo "15 oct 2026, 12:50:41". Los segundos
    /// distinguen capturas casi simultáneas del mismo pago.
    public static func timestampText(_ date: Date) -> String {
        var style = Date.FormatStyle(date: .abbreviated, time: .standard)
        style.timeZone = timeZone
        return date.formatted(style.locale(Locale(identifier: "es_PA")))
    }
}
