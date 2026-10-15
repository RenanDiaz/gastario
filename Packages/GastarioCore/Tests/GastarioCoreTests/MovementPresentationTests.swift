import Foundation
import Testing
@testable import GastarioCore

struct MovementPresentationTests {
    @Test func montoConSigno() {
        #expect(MovementPresentation.amountText(amount: Decimal(string: "3.80")!, direction: .outflow, issues: []) == "-$3.80")
        #expect(MovementPresentation.amountText(amount: Decimal(string: "1250")!, direction: .inflow, issues: []) == "+$1,250.00")
    }

    /// Q5: un monto que no se pudo leer se muestra como "—", no como "$0.00".
    @Test func montoIlegibleEsRaya() {
        #expect(MovementPresentation.amountText(amount: 0, direction: .outflow, issues: [.amount]) == "—")
        #expect(MovementPresentation.amountText(amount: 0, direction: .outflow, issues: []) == "-$0.00")
    }

    /// 23:30 y 00:10 en Panamá son días distintos, aunque en UTC caigan el mismo día.
    @Test func agrupaPorDiaEnPanama() {
        let iso = ISO8601DateFormatter()
        let dates = [
            iso.date(from: "2026-10-07T23:30:00-05:00")!,
            iso.date(from: "2026-10-08T00:10:00-05:00")!,
            iso.date(from: "2026-10-08T09:00:00-05:00")!,
        ]
        let groups = MovementPresentation.groupedByDay(dates) { $0 }
        #expect(groups.count == 2)
        #expect(groups.map(\.items.count) == [2, 1])
        #expect(groups[0].day == iso.date(from: "2026-10-08T00:00:00-05:00")!)
        #expect(groups[1].day == iso.date(from: "2026-10-07T00:00:00-05:00")!)
    }

    @Test func horaConSegundosEnPanama() {
        let date = ISO8601DateFormatter().date(from: "2026-10-15T17:50:41Z")!
        let text = MovementPresentation.timestampText(date)
        #expect(text.contains("12:50:41"))
        #expect(text.contains("2026"))
    }

    @Test func tituloDelDiaEnEspanol() {
        let day = ISO8601DateFormatter().date(from: "2026-10-07T00:00:00-05:00")!
        let title = MovementPresentation.dayTitle(day)
        #expect(title.contains("7"))
        #expect(title.lowercased().contains("octubre"))
    }
}

struct MonthlySummaryTests {
    struct Item {
        let amount: Decimal
        let direction: Direction
        let date: Date
    }

    func summary(_ items: [Item], at iso: String) -> MonthlySummary {
        MovementPresentation.monthlySummary(
            items, containing: ISO8601DateFormatter().date(from: iso)!,
            amount: \.amount, direction: \.direction, occurredAt: \.date)
    }

    /// 23:30 del 30 de septiembre en Panamá es 1 de octubre en UTC: cuenta en septiembre.
    @Test func limiteDeMesEnPanama() {
        let iso = ISO8601DateFormatter()
        let items = [
            Item(amount: 10, direction: .outflow, date: iso.date(from: "2026-09-30T23:30:00-05:00")!),
            Item(amount: 3, direction: .outflow, date: iso.date(from: "2026-10-01T00:00:00-05:00")!),
            Item(amount: 100, direction: .inflow, date: iso.date(from: "2026-10-15T12:00:00-05:00")!),
            Item(amount: 7, direction: .outflow, date: iso.date(from: "2026-11-01T00:00:00-05:00")!),
        ]
        #expect(summary(items, at: "2026-10-15T12:00:00-05:00") == MonthlySummary(outflow: 3, inflow: 100))
        #expect(summary(items, at: "2026-10-15T12:00:00-05:00").net == 97)
        #expect(summary(items, at: "2026-09-10T12:00:00-05:00") == MonthlySummary(outflow: 10, inflow: 0))
    }

    @Test func tituloDelMes() {
        let date = ISO8601DateFormatter().date(from: "2026-10-15T12:00:00-05:00")!
        #expect(MovementPresentation.monthTitle(date).lowercased().contains("octubre"))
    }

    @Test func filtros() {
        #expect(MovementFilter.all.matches(hasNote: true, status: .ok))
        #expect(MovementFilter.noNote.matches(hasNote: false, status: .ok))
        #expect(!MovementFilter.noNote.matches(hasNote: true, status: .failed))
        #expect(MovementFilter.needsReview.matches(hasNote: true, status: .partial))
        #expect(!MovementFilter.needsReview.matches(hasNote: false, status: .ok))
    }
}
