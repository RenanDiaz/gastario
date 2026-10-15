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

    @Test func tituloDelDiaEnEspanol() {
        let day = ISO8601DateFormatter().date(from: "2026-10-07T00:00:00-05:00")!
        let title = MovementPresentation.dayTitle(day)
        #expect(title.contains("7"))
        #expect(title.lowercased().contains("octubre"))
    }
}
