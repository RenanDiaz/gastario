import Foundation
import SwiftData
import Testing
@testable import GastarioCore

/// Swift Testing también exporta `Attachment`; la declaración local gana sobre los imports.
fileprivate typealias Attachment = GastarioCore.Attachment

/// `@MainActor`: SwiftData no admite crear containers y modelos en paralelo desde varios hilos;
/// las suites que lo usan corren todas en el hilo principal (SPEC §3).
@MainActor
struct StoreTests {
    private let occurredAt = ISO8601DateFormatter().date(from: "2026-10-07T11:53:00-05:00")!

    @Test func insertarYLeer() throws {
        let container = GastarioStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let movement = Movement(
            source: .yappy, direction: .outflow, amount: Decimal(string: "600.00")!,
            counterparty: "Ana Morales", occurredAt: occurredAt)
        movement.confirmation = "KTRWA-10293847"
        context.insert(movement)
        try context.save()

        let fetched = try ModelContext(container).fetch(FetchDescriptor<Movement>())
        #expect(fetched.count == 1)
        let read = try #require(fetched.first)
        #expect(read.id == movement.id)
        #expect(read.source == .yappy)
        #expect(read.direction == .outflow)
        #expect(read.amount == Decimal(string: "600")!)
        #expect(read.counterparty == "Ana Morales")
        #expect(read.confirmation == "KTRWA-10293847")
        #expect(read.occurredAt == occurredAt)
        #expect(read.parseStatus == .ok)
    }

    /// AC-15 (mitad de datos): borrar un movimiento borra sus adjuntos.
    @Test func borrarEnCascada() throws {
        let container = GastarioStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let movement = Movement(source: .card, direction: .outflow, amount: 3, occurredAt: occurredAt)
        context.insert(movement)
        movement.attachments.append(Attachment(kind: .pdf, data: Data([0x25, 0x50]), filename: "factura.pdf"))
        movement.attachments.append(Attachment(kind: .link, url: URL(string: "https://dgi-fep.mef.gob.pa/x")))
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Attachment>()) == 2)

        context.delete(movement)
        try context.save()

        let fresh = ModelContext(container)
        #expect(try fresh.fetchCount(FetchDescriptor<Movement>()) == 0)
        #expect(try fresh.fetchCount(FetchDescriptor<Attachment>()) == 0)
    }

    @Test func conjuntosSobrevivenGuardarYLeer() throws {
        let container = GastarioStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let movement = Movement(
            source: .card, direction: .outflow, amount: 0, occurredAt: occurredAt,
            parseStatus: .partial, parseIssues: [.amount, .counterparty])
        movement.editedFields = [.occurredAt]
        context.insert(movement)
        try context.save()

        let read = try #require(try ModelContext(container).fetch(FetchDescriptor<Movement>()).first)
        #expect(read.parseIssues == [.amount, .counterparty])
        #expect(read.editedFields == [.occurredAt])
        #expect(read.parseStatus == .partial)
        #expect(read.needsReview)
    }

    /// Los filtros de la Fase 4 dependen de poder filtrar por el valor crudo.
    @Test func predicadoSobreEstadoCrudo() throws {
        let container = GastarioStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        context.insert(Movement(source: .card, direction: .outflow, amount: 1, occurredAt: occurredAt))
        context.insert(Movement(
            source: .yappy, direction: .inflow, amount: 2, occurredAt: occurredAt,
            parseStatus: .failed, parseIssues: [.direction]))
        try context.save()

        let ok = ParseStatus.ok.rawValue
        let review = try context.fetch(FetchDescriptor<Movement>(predicate: #Predicate { $0.parseStatusRaw != ok }))
        #expect(review.map(\.parseStatus) == [.failed])
    }
}
