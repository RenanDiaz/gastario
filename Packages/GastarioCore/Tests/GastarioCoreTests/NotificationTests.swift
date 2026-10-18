import Foundation
import SwiftData
import Testing
@testable import GastarioCore

struct NotificationTextTests {
    @Test func salida() {
        let text = NotificationText.build(
            source: .yappy, direction: .outflow, amount: Decimal(string: "3.80")!, counterparty: "M/S Betty",
            cardName: nil, status: .ok, issues: [])
        #expect(text == NotificationText(title: "Gasto", body: "¿En qué gastaste $3.80 en M/S Betty?"))
    }

    @Test func entrada() {
        let text = NotificationText.build(
            source: .yappy, direction: .inflow, amount: Decimal(string: "123.20")!, counterparty: "Miguel E.",
            cardName: nil, status: .ok, issues: [])
        #expect(text == NotificationText(title: "Ingreso", body: "¿Por qué te enviaron $123.20? (Miguel E.)"))
    }

    /// AC-12.
    @Test(arguments: [
        (Set<ParseIssue>([.amount]), "el monto"),
        (Set<ParseIssue>([.counterparty]), "el comercio"),
        (Set<ParseIssue>([.amount, .counterparty]), "el monto ni el comercio"),
    ])
    func tarjetaIncompleta(issues: Set<ParseIssue>, missing: String) {
        let text = NotificationText.build(
            source: .card, direction: .outflow, amount: 0, counterparty: nil,
            cardName: "Visa", status: .partial, issues: issues)
        #expect(text == NotificationText(
            title: "Revisar movimiento",
            body: "Pagaste con Visa, pero no pude leer \(missing). Complétalo en la app."))
    }

    /// AC-7.
    @Test func yappyFailed() {
        let text = NotificationText.build(
            source: .yappy, direction: .outflow, amount: 0, counterparty: nil,
            cardName: nil, status: .failed, issues: [.direction, .amount])
        #expect(text == NotificationText(title: "Revisar movimiento", body: "No pude leer un Yappy, revísalo en la app."))
    }

    @Test func tarjetaFailed() {
        let text = NotificationText.build(
            source: .card, direction: .outflow, amount: 0, counterparty: nil,
            cardName: nil, status: .failed, issues: [.amount, .counterparty])
        #expect(text.body == "No pude leer un pago con tarjeta, revísalo en la app.")
    }

    @Test func yappyParcialSinContraparte() {
        let text = NotificationText.build(
            source: .yappy, direction: .outflow, amount: Decimal(string: "49.06")!, counterparty: nil,
            cardName: nil, status: .partial, issues: [.counterparty])
        #expect(text.body == "¿En qué gastaste $49.06?")
    }

    @Test func montoConComa() {
        let text = NotificationText.build(
            source: .card, direction: .outflow, amount: Decimal(string: "1250")!, counterparty: "SUPER 99",
            cardName: "Visa", status: .ok, issues: [])
        #expect(text.body == "¿En qué gastaste $1,250.00 en SUPER 99?")
    }
}

@MainActor
struct NoteReplyHandlerTests {
    let container = GastarioStore.makeContainer(inMemory: true)
    let now = ISO8601DateFormatter().date(from: "2026-10-15T20:00:00-05:00")!

    func insertMovement() throws -> UUID {
        let context = ModelContext(container)
        let movement = Movement(source: .yappy, direction: .outflow, amount: 40, occurredAt: now)
        context.insert(movement)
        try context.save()
        return movement.id
    }

    /// AC-8 (parte de datos).
    @Test func guardaNotaYFecha() async throws {
        let id = try insertMovement()
        let saved = await NoteReplyHandler(container: container).handle(movementID: id, text: "  Cuerdas  ", at: now)
        #expect(saved)
        let movement = try #require(try ModelContext(container).fetch(FetchDescriptor<Movement>()).first)
        #expect(movement.note == "Cuerdas")
        #expect(movement.notedAt == now)
    }

    @Test func idInexistenteNoLanza() async {
        let saved = await NoteReplyHandler(container: container).handle(movementID: UUID(), text: "Cuerdas")
        #expect(!saved)
    }

    @Test func respuestaVaciaSeIgnora() async throws {
        let id = try insertMovement()
        let saved = await NoteReplyHandler(container: container).handle(movementID: id, text: "   ")
        #expect(!saved)
        #expect(try ModelContext(container).fetch(FetchDescriptor<Movement>()).first?.note == nil)
    }
}
