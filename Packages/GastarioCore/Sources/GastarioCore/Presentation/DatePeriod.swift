import Foundation

/// Período de la lista (SPEC Fase 4a, C19). Meses y días en `America/Panama`, igual que C9.
public enum DatePeriod: Hashable, Sendable {
    case all
    case thisMonth
    case previousMonth
    /// Días completos en Panamá, ambos incluidos. Solo cuenta el día de cada fecha.
    case range(from: Date, to: Date)

    /// Las opciones del menú; `range` abre la hoja de fechas.
    public enum Kind: String, CaseIterable, Identifiable, Sendable {
        case all, thisMonth, previousMonth, range

        public var id: Self { self }

        public var title: String {
            switch self {
            case .all: "Todo"
            case .thisMonth: "Este mes"
            case .previousMonth: "Mes anterior"
            case .range: "Rango…"
            }
        }
    }

    public var kind: Kind {
        switch self {
        case .all: .all
        case .thisMonth: .thisMonth
        case .previousMonth: .previousMonth
        case .range: .range
        }
    }

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = MovementPresentation.timeZone
        return calendar
    }

    /// Intervalo semiabierto `[start, end)`; `nil` = sin límite ("Todo").
    public func interval(now: Date) -> DateInterval? {
        let calendar = Self.calendar
        switch self {
        case .all:
            return nil
        case .thisMonth:
            return calendar.dateInterval(of: .month, for: now)
        case .previousMonth:
            guard let current = calendar.dateInterval(of: .month, for: now),
                  let previousDay = calendar.date(byAdding: .day, value: -1, to: current.start)
            else { return nil }
            return calendar.dateInterval(of: .month, for: previousDay)
        case .range(let from, let to):
            let start = calendar.startOfDay(for: min(from, to))
            let lastDay = calendar.startOfDay(for: max(from, to))
            guard let end = calendar.date(byAdding: .day, value: 1, to: lastDay) else { return nil }
            return DateInterval(start: start, end: end)
        }
    }

    public func contains(_ date: Date, now: Date) -> Bool {
        guard let interval = interval(now: now) else { return true }
        return date >= interval.start && date < interval.end
    }

    /// "Todo", "Septiembre de 2026" o "1 sep – 15 oct 2026".
    public func title(now: Date) -> String {
        switch self {
        case .all:
            return Kind.all.title
        case .thisMonth, .previousMonth:
            guard let interval = interval(now: now) else { return kind.title }
            return MovementPresentation.monthTitle(interval.start)
        case .range:
            guard let interval = interval(now: now),
                  let last = Self.calendar.date(byAdding: .day, value: -1, to: interval.end)
            else { return kind.title }
            return Self.rangeTitle(from: interval.start, to: last)
        }
    }

    static func rangeTitle(from: Date, to: Date) -> String {
        let calendar = calendar
        let locale = Locale(identifier: "es_PA")
        var withYear = Date.FormatStyle().day().month(.abbreviated).year()
        withYear.timeZone = MovementPresentation.timeZone
        withYear = withYear.locale(locale)
        if calendar.isDate(from, inSameDayAs: to) { return to.formatted(withYear) }
        var withoutYear = Date.FormatStyle().day().month(.abbreviated)
        withoutYear.timeZone = MovementPresentation.timeZone
        withoutYear = withoutYear.locale(locale)
        let sameYear = calendar.component(.year, from: from) == calendar.component(.year, from: to)
        let start = from.formatted(sameYear ? withoutYear : withYear)
        return "\(start) – \(to.formatted(withYear))"
    }
}
