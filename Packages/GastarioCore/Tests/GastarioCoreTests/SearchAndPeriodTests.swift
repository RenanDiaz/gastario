import Foundation
import Testing
@testable import GastarioCore

/// Búsqueda de la lista (SPEC Fase 4a).
struct MovementSearchTests {
    func matches(_ text: String, _ fields: [String?], amount: Decimal = 1) -> Bool {
        MovementSearch(text: text).matches(fields: fields, amount: amount)
    }

    @Test func sinMayusculasNiAcentos() {
        #expect(matches("cafe", ["Café Unido"]))
        #expect(matches("CAFÉ", ["cafe unido"]))
        #expect(matches("panama", [nil, "Ciudad de Panamá"]))
    }

    /// AC-32: cada palabra tiene que estar en algún campo, en cualquier orden.
    @Test func variasPalabrasEnCamposDistintos() {
        let fields: [String?] = ["Super 99", "leche y pan", nil]
        #expect(matches("leche super", fields))
        #expect(!matches("leche arroz", fields))
    }

    @Test func vaciaCoincideConTodo() {
        #expect(MovementSearch(text: "").isEmpty)
        #expect(MovementSearch(text: "   ").isEmpty)
        #expect(matches("  ", [nil]))
        #expect(!matches("x", [nil, nil]))
    }

    /// AC-33: un término numérico compara con el inicio del monto.
    @Test func porMonto() {
        #expect(matches("49", [], amount: Decimal(string: "49.06")!))
        #expect(matches("49", [], amount: 490))
        #expect(!matches("49", [], amount: Decimal(string: "4.90")!))
        #expect(matches("$49.06", [], amount: Decimal(string: "49.06")!))
        #expect(matches("49.0", [], amount: Decimal(string: "49.06")!))
        #expect(!matches("49.0", [], amount: Decimal(string: "49.60")!))
        #expect(matches("1250", [], amount: 1250))
    }

    @Test func montoCeroNoCoincidePorMonto() {
        #expect(!matches("0", [], amount: 0))
        #expect(!matches("0.00", ["Comercio"], amount: 0))
    }

    @Test func terminoNumericoTambienBuscaTexto() {
        #expect(matches("99", ["Super 99"], amount: Decimal(string: "12.50")!))
    }

    @Test func terminoNoNumerico() {
        #expect(MovementSearch.numericTerm("4.5.6") == nil)
        #expect(MovementSearch.numericTerm("$") == nil)
        #expect(MovementSearch.numericTerm("1,250") == nil)
        #expect(MovementSearch.numericTerm("$4.5") == "4.5")
    }
}

/// Período de la lista (SPEC Fase 4a). Meses y días en Panamá.
struct DatePeriodTests {
    let iso = ISO8601DateFormatter()
    func date(_ text: String) -> Date { iso.date(from: text)! }

    /// Las 23:30 del 30 de septiembre en Panamá son el 1 de octubre en UTC: cuenta en septiembre.
    @Test func esteMesYMesAnteriorEnPanama() {
        let now = date("2026-10-15T12:00:00-05:00")
        let lateSeptember = date("2026-09-30T23:30:00-05:00")
        #expect(!DatePeriod.thisMonth.contains(lateSeptember, now: now))
        #expect(DatePeriod.previousMonth.contains(lateSeptember, now: now))
        #expect(DatePeriod.thisMonth.contains(date("2026-10-01T00:00:00-05:00"), now: now))
        #expect(!DatePeriod.thisMonth.contains(date("2026-11-01T00:00:00-05:00"), now: now))
        #expect(DatePeriod.all.contains(lateSeptember, now: now))
        #expect(DatePeriod.all.interval(now: now) == nil)
    }

    @Test func mesAnteriorEnEnero() {
        let now = date("2027-01-10T12:00:00-05:00")
        let interval = DatePeriod.previousMonth.interval(now: now)!
        #expect(interval.start == date("2026-12-01T00:00:00-05:00"))
        #expect(interval.end == date("2027-01-01T00:00:00-05:00"))
    }

    /// "Hasta" incluye su último minuto en Panamá y excluye las 00:00 del día siguiente.
    @Test func rangoIncluyeElUltimoDia() {
        let now = date("2026-10-15T12:00:00-05:00")
        // La hora de "Desde" y "Hasta" no importa: solo cuenta el día en Panamá.
        let period = DatePeriod.range(
            from: date("2026-09-01T15:00:00-05:00"), to: date("2026-10-15T08:00:00-05:00"))
        #expect(period.contains(date("2026-09-01T00:00:00-05:00"), now: now))
        #expect(period.contains(date("2026-10-15T23:59:00-05:00"), now: now))
        #expect(!period.contains(date("2026-10-16T00:00:00-05:00"), now: now))
        #expect(!period.contains(date("2026-08-31T23:59:00-05:00"), now: now))
    }

    @Test func rangoDeUnSoloDia() {
        let day = date("2026-10-07T10:00:00-05:00")
        let period = DatePeriod.range(from: day, to: day)
        #expect(period.contains(date("2026-10-07T00:00:00-05:00"), now: day))
        #expect(period.contains(date("2026-10-07T23:59:59-05:00"), now: day))
        #expect(!period.contains(date("2026-10-08T00:00:00-05:00"), now: day))
        #expect(period.title(now: day).hasPrefix("7 oct"))
        #expect(period.title(now: day).hasSuffix(" 2026"))
        #expect(!period.title(now: day).contains("–"))
    }

    @Test func titulos() {
        let now = date("2026-10-15T12:00:00-05:00")
        #expect(DatePeriod.all.title(now: now) == "Todo")
        #expect(DatePeriod.thisMonth.title(now: now) == "Octubre de 2026")
        #expect(DatePeriod.previousMonth.title(now: now) == "Septiembre de 2026")
        let range = DatePeriod.range(
            from: date("2026-09-01T12:00:00-05:00"), to: date("2026-10-15T12:00:00-05:00"))
        // La abreviatura del mes depende de los datos de CLDR ("sep" o "sept", con o sin punto):
        // se fija la forma, no el texto exacto.
        let title = range.title(now: now)
        #expect(title.hasPrefix("1 sep"))
        #expect(title.contains(" – 15 oct"))
        #expect(title.hasSuffix(" 2026"))
        #expect(title.components(separatedBy: "2026").count == 2)
        let acrossYears = DatePeriod.range(
            from: date("2026-12-20T12:00:00-05:00"), to: date("2027-01-05T12:00:00-05:00"))
        let acrossTitle = acrossYears.title(now: now)
        #expect(acrossTitle.hasPrefix("20 dic"))
        #expect(acrossTitle.contains(" 2026 – 5 ene"))
        #expect(acrossTitle.hasSuffix("2027"))
    }

    @Test func resumenPorIntervaloIgualAlMensual() {
        struct Item { let amount: Decimal; let direction: Direction; let date: Date }
        let items = [
            Item(amount: 10, direction: .outflow, date: date("2026-09-30T23:30:00-05:00")),
            Item(amount: 3, direction: .outflow, date: date("2026-10-01T00:00:00-05:00")),
            Item(amount: 100, direction: .inflow, date: date("2026-10-15T12:00:00-05:00")),
        ]
        let now = date("2026-10-15T12:00:00-05:00")
        let monthly = MovementPresentation.monthlySummary(
            items, containing: now, amount: \.amount, direction: \.direction, occurredAt: \.date)
        let byInterval = MovementPresentation.summary(
            items, in: DatePeriod.thisMonth.interval(now: now)!,
            amount: \.amount, direction: \.direction, occurredAt: \.date)
        #expect(monthly == byInterval)
        #expect(MovementPresentation.totals(items, amount: \.amount, direction: \.direction)
            == MonthlySummary(outflow: 13, inflow: 100))
    }
}
