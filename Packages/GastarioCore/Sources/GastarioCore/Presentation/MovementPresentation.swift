import Foundation
import GastarioParsing

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
