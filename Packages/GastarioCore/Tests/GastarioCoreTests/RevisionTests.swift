import Foundation
import SwiftData
import Testing
@testable import GastarioCore

fileprivate typealias Attachment = GastarioCore.Attachment

@MainActor
struct ReparseServiceTests {
    let container = GastarioStore.makeContainer(inMemory: true)
    let capturedAt = ISO8601DateFormatter().date(from: "2026-10-15T12:00:00-05:00")!

    /// Movimiento con crudo bueno y campos "corruptos", como si lo hubiera parseado un parser viejo.
    func corruptedYappy(in context: ModelContext) -> Movement {
        let movement = Movement(
            source: .yappy, direction: .outflow, amount: 0, occurredAt: capturedAt, capturedAt: capturedAt,
            parseStatus: .failed, parseIssues: Set(ParseIssue.allCases))
        movement.rawContent = YappyBodies.sent()
        context.insert(movement)
        return movement
    }

    /// AC-17 y AC-18.
    @Test func restauraYConservaLoEditado() throws {
        let context = ModelContext(container)
        let movement = corruptedYappy(in: context)
        movement.counterparty = "Editado a mano"
        movement.editedFields = [.counterparty]
        movement.note = "Cuerdas"
        movement.notedAt = capturedAt
        movement.attachments.append(Attachment(kind: .link, url: URL(string: "https://example.com")))
        try context.save()

        let changed = ReparseService().reparse(movement)
        try context.save()

        #expect(changed)
        #expect(movement.amount == Decimal(string: "40")!)
        #expect(movement.confirmation == "KTRWA-10293847")
        #expect(movement.counterparty == "Editado a mano")
        #expect(movement.editedFields == [.counterparty])
        #expect(movement.note == "Cuerdas")
        #expect(movement.notedAt == capturedAt)
        #expect(movement.attachments.count == 1)
        #expect(movement.parseStatus == .ok)
        #expect(movement.parseIssues.isEmpty)
    }

    @Test func tarjetaDesdeRawInputs() throws {
        let context = ModelContext(container)
        let movement = Movement(
            source: .card, direction: .outflow, amount: 0, occurredAt: capturedAt, capturedAt: capturedAt,
            parseStatus: .failed, parseIssues: [.amount, .counterparty])
        movement.rawInputs = #"{"amount":"$3.80","cardName":"Visa","merchant":"SUPER 99"}"#
        context.insert(movement)

        #expect(ReparseService().reparse(movement))
        #expect(movement.amount == Decimal(string: "3.80")!)
        #expect(movement.counterparty == "SUPER 99")
        #expect(movement.parseStatus == .ok)
    }

    @Test func sinCambiosDevuelveFalse() throws {
        let context = ModelContext(container)
        let movement = corruptedYappy(in: context)
        let service = ReparseService()
        #expect(service.reparse(movement))
        #expect(!service.reparse(movement))
    }

    @Test func reparseAllIgnoraOkYManual() throws {
        let context = ModelContext(container)
        _ = corruptedYappy(in: context)
        let ok = Movement(source: .yappy, direction: .outflow, amount: 5, occurredAt: capturedAt)
        ok.rawContent = "cuerpo que ya no parsea"
        context.insert(ok)
        let manual = Movement.manual(
            amount: 12, direction: .outflow, counterparty: "Taxi", occurredAt: capturedAt, note: nil)
        manual.parseStatus = .failed
        context.insert(manual)
        try context.save()

        let changed = try ReparseService().reparseAll(in: context)

        #expect(changed == 1)
        #expect(ok.parseStatus == .ok)
        #expect(ok.amount == 5)
        #expect(manual.parseStatus == .failed)
    }
}

/// `@MainActor`: crea modelos de SwiftData (ver `StoreTests`).
@MainActor
struct MovementEditorTests {
    let date = ISO8601DateFormatter().date(from: "2026-10-15T12:00:00-05:00")!

    /// AC-13.
    @Test func parcialPasaAOkAlResolverElUltimoCampo() {
        let movement = Movement(
            source: .card, direction: .outflow, amount: 0, counterparty: nil, occurredAt: date,
            parseStatus: .partial, parseIssues: [.amount, .counterparty])

        MovementEditor.setAmount(Decimal(string: "3.80")!, on: movement)
        #expect(movement.parseStatus == .partial)
        #expect(movement.parseIssues == [.counterparty])

        MovementEditor.setCounterparty("  SUPER 99 ", on: movement)
        #expect(movement.counterparty == "SUPER 99")
        #expect(movement.parseStatus == .ok)
        #expect(movement.parseIssues.isEmpty)
        #expect(movement.editedFields == [.amount, .counterparty])
    }

    @Test func failedNoCambiaPorEdicion() {
        let movement = Movement(
            source: .yappy, direction: .outflow, amount: 0, occurredAt: date,
            parseStatus: .failed, parseIssues: [.direction, .amount])
        MovementEditor.setAmount(10, on: movement)
        #expect(movement.parseStatus == .failed)
        #expect(movement.parseIssues == [.direction])
        #expect(movement.editedFields == [.amount])
    }

    @Test func valoresInvalidosSeIgnoran() {
        let movement = Movement(
            source: .card, direction: .outflow, amount: 0, occurredAt: date,
            parseStatus: .partial, parseIssues: [.amount, .counterparty])
        MovementEditor.setAmount(0, on: movement)
        MovementEditor.setCounterparty("   ", on: movement)
        #expect(movement.editedFields.isEmpty)
        #expect(movement.parseIssues == [.amount, .counterparty])
    }

    @Test func notaAsignaNotedAtUnaVez() {
        let movement = Movement(source: .yappy, direction: .outflow, amount: 1, occurredAt: date)
        MovementEditor.setNote("Cuerdas", on: movement, at: date)
        #expect(movement.note == "Cuerdas")
        #expect(movement.notedAt == date)

        MovementEditor.setNote("Cuerdas de guitarra", on: movement, at: date.addingTimeInterval(60))
        #expect(movement.notedAt == date)

        MovementEditor.setNote("  ", on: movement)
        #expect(movement.note == nil)
        #expect(movement.notedAt == nil)
    }

    /// AC-14.
    @Test func entradaManual() {
        let movement = Movement.manual(
            amount: Decimal(string: "12.50")!, direction: .outflow, counterparty: " Taxi ",
            occurredAt: date, note: "Al aeropuerto", at: date)
        #expect(movement.source == .manual)
        #expect(movement.parseStatus == .ok)
        #expect(movement.counterparty == "Taxi")
        #expect(movement.note == "Al aeropuerto")
        #expect(movement.notedAt == date)
    }
}
