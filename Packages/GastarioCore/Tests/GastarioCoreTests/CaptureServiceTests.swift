import Foundation
import SwiftData
import Testing
@testable import GastarioCore

@MainActor
final class SpyNotifier: MovementNotifier {
    private(set) var notified: [UUID] = []
    func notify(movementID: UUID) async { notified.append(movementID) }
}

@MainActor
final class SpyBackup: BackupTrigger {
    private(set) var runs = 0
    func runIfDue() async { runs += 1 }
}

struct ThrowingParser: CaptureParser {
    struct Boom: Error {}
    func parseCard(_ inputs: CardRawInputs) throws -> ParsedCard { throw Boom() }
    func parseYappy(_ content: String) throws -> ParsedYappy { throw Boom() }
}

/// Falla si al momento de parsear el crudo todavía no está en el store (principio 2).
struct StoreProbeParser: CaptureParser {
    struct RawNotSaved: Error {}
    let container: ModelContainer

    func parseCard(_ inputs: CardRawInputs) throws -> ParsedCard {
        try requireSavedRaw()
        return CardInputParser.parse(inputs)
    }

    func parseYappy(_ content: String) throws -> ParsedYappy {
        try requireSavedRaw()
        return YappyEmailParser.parse(content)
    }

    private func requireSavedRaw() throws {
        let saved = try ModelContext(container).fetch(FetchDescriptor<Movement>())
        guard saved.count == 1, saved[0].rawContent != nil || saved[0].rawInputs != nil else {
            throw RawNotSaved()
        }
    }
}

enum YappyBodies {
    static func sent(confirmation: String = "KTRWA-10293847") -> String {
        """
        Enviaste por Yappy
        $40.00
        Enviado a
        Ana Morales
        Fecha
        07 oct 2026 12:30 p.\u{00A0}m.
        Mensaje
        Cuerdas
        Confirmación
        \(confirmation)
        """
    }

    static let paidToStore = """
        Pagaste por Yappy
        $10.11
        Pagado a
        Venta de Entradas
        Fecha
        30 sept 2026 07:59 p.\u{00A0}m.
        Mensaje
        Por pedido ABCD1234EFGH
        Confirmación
        MNBVC-99887766
        """

    static let storeReceived = """
        ¡Hola!
        Recibiste una compra en línea por Yappy en https://tienda.example.com.
        Cliente: Pedro Gomez
        Monto:$10.11
        Fecha: 30 sept 2026 07:59 p.\u{00A0}m.
        Confirmación: MNBVC-99887766
        Número de pedido: ABCD1234EFGH
        """
}

@MainActor
struct CaptureServiceTests {
    let container = GastarioStore.makeContainer(inMemory: true)
    let notifier = SpyNotifier()
    let backup = SpyBackup()
    let capturedAt = ISO8601DateFormatter().date(from: "2026-10-15T12:00:00-05:00")!

    func service(parser: any CaptureParser = DefaultCaptureParser()) -> CaptureService {
        CaptureService(container: container, parser: parser, notifier: notifier, backup: backup)
    }

    func movements() throws -> [Movement] {
        try ModelContext(container).fetch(FetchDescriptor<Movement>(sortBy: [SortDescriptor(\.capturedAt)]))
    }

    /// AC-1 sin la notificación.
    @Test func tarjetaCompleta() async throws {
        let inputs = CardRawInputs(
            merchant: "SUPER 99", amount: "$3.80", cardName: "Visa", city: "Panamá", latitude: 8.98, longitude: -79.52)
        let outcome = try await service().captureCard(inputs, capturedAt: capturedAt)

        let saved = try #require(try movements().first)
        #expect(outcome == .created(saved.id))
        #expect(saved.source == .card)
        #expect(saved.direction == .outflow)
        #expect(saved.amount == Decimal(string: "3.80")!)
        #expect(saved.counterparty == "SUPER 99")
        #expect(saved.cardName == "Visa")
        #expect(saved.city == "Panamá")
        #expect(saved.occurredAt == capturedAt)
        #expect(saved.parseStatus == .ok)
        #expect(saved.parseIssues.isEmpty)
        #expect(notifier.notified == [saved.id])
        #expect(backup.runs == 1)

        let raw = try #require(saved.rawInputs?.data(using: .utf8))
        #expect(try JSONDecoder().decode(CardRawInputs.self, from: raw) == inputs)
    }

    /// AC-12.
    @Test(arguments: [
        (CardRawInputs(merchant: "SUPER 99", amount: "0", cardName: "Visa"), Set<ParseIssue>([.amount])),
        (CardRawInputs(merchant: "", amount: "$3.80", cardName: "Visa"), Set<ParseIssue>([.counterparty])),
    ])
    func tarjetaConDatosVacios(inputs: CardRawInputs, issues: Set<ParseIssue>) async throws {
        _ = try await service().captureCard(inputs, capturedAt: capturedAt)
        let saved = try #require(try movements().first)
        #expect(saved.parseStatus == .partial)
        #expect(saved.parseIssues == issues)
        #expect(notifier.notified.count == 1)
    }

    /// AC-10.
    @Test func tarjetaSinUbicacion() async throws {
        _ = try await service().captureCard(
            CardRawInputs(merchant: "SUPER 99", amount: "3.80", cardName: "Visa"), capturedAt: capturedAt)
        let saved = try #require(try movements().first)
        #expect(saved.city == nil)
        #expect(saved.latitude == nil)
        #expect(saved.longitude == nil)
        #expect(saved.parseStatus == .ok)
    }

    @Test func yappyEnviado() async throws {
        _ = try await service().captureYappy(content: YappyBodies.sent(), capturedAt: capturedAt)
        let saved = try #require(try movements().first)
        #expect(saved.source == .yappy)
        #expect(saved.direction == .outflow)
        #expect(saved.amount == Decimal(string: "40")!)
        #expect(saved.counterparty == "Ana Morales")
        #expect(saved.yappyMessage == "Cuerdas")
        #expect(saved.confirmation == "KTRWA-10293847")
        #expect(saved.occurredAt == ISO8601DateFormatter().date(from: "2026-10-07T12:30:00-05:00")!)
        #expect(saved.rawContent == YappyBodies.sent())
        #expect(saved.parseStatus == .ok)
    }

    /// AC-6: el duplicado no crea, no modifica el existente (ni su nota) y no notifica.
    @Test func duplicadoConservaNota() async throws {
        let first = try await service().captureYappy(content: YappyBodies.sent(), capturedAt: capturedAt)
        let context = ModelContext(container)
        let original = try #require(try context.fetch(FetchDescriptor<Movement>()).first)
        original.note = "Cuerdas para la guitarra"
        try context.save()

        let second = try await service().captureYappy(
            content: YappyBodies.sent(), capturedAt: capturedAt.addingTimeInterval(60))

        let saved = try movements()
        #expect(saved.count == 1)
        #expect(second == .duplicate(existing: original.id))
        #expect(first == .created(original.id))
        #expect(saved.first?.note == "Cuerdas para la guitarra")
        #expect(notifier.notified == [original.id])
    }

    /// C11: el mismo pago visto desde la cuenta personal y desde Yappy Comercial son dos movimientos.
    @Test func mismaConfirmacionDistintaDireccion() async throws {
        _ = try await service().captureYappy(content: YappyBodies.paidToStore, capturedAt: capturedAt)
        _ = try await service().captureYappy(content: YappyBodies.storeReceived, capturedAt: capturedAt)
        let saved = try movements()
        #expect(saved.count == 2)
        #expect(Set(saved.map(\.direction)) == [.outflow, .inflow])
        #expect(notifier.notified.count == 2)
    }

    /// AC-5.
    @Test func dosCorreosDistintos() async throws {
        _ = try await service().captureYappy(content: YappyBodies.sent(confirmation: "AAAAA-11111111"), capturedAt: capturedAt)
        _ = try await service().captureYappy(content: YappyBodies.sent(confirmation: "BBBBB-22222222"), capturedAt: capturedAt)
        #expect(try movements().count == 2)
        #expect(notifier.notified.count == 2)
    }

    /// AC-7 (parte de datos).
    @Test func cuerpoInesperadoEsFailed() async throws {
        let body = "Tu estado de cuenta ya está disponible."
        _ = try await service().captureYappy(content: body, capturedAt: capturedAt)
        let saved = try #require(try movements().first)
        #expect(saved.parseStatus == .failed)
        #expect(saved.rawContent == body)
        #expect(saved.occurredAt == capturedAt)
        #expect(notifier.notified == [saved.id])
    }

    /// Principio 2: si el parser falla, el crudo ya está guardado y el movimiento queda `failed`.
    @Test func parserQueLanzaDejaElCrudo() async throws {
        let outcome = try await service(parser: ThrowingParser()).captureYappy(
            content: YappyBodies.sent(), capturedAt: capturedAt)
        let saved = try #require(try movements().first)
        #expect(outcome == .created(saved.id))
        #expect(saved.parseStatus == .failed)
        #expect(saved.rawContent == YappyBodies.sent())
        #expect(notifier.notified == [saved.id])

        _ = try await service(parser: ThrowingParser()).captureCard(
            CardRawInputs(merchant: "SUPER 99", amount: "3.80", cardName: "Visa"), capturedAt: capturedAt)
        let card = try #require(try movements().first { $0.source == .card })
        #expect(card.parseStatus == .failed)
        #expect(card.rawInputs != nil)
    }

    /// Principio 2: el crudo está en el store **antes** de parsear.
    @Test func crudoGuardadoAntesDeParsear() async throws {
        let probe = StoreProbeParser(container: container)
        _ = try await service(parser: probe).captureYappy(content: YappyBodies.sent(), capturedAt: capturedAt)
        #expect(try movements().first?.parseStatus == .ok)
    }

    /// Re-parseo (Fase 4): un campo editado a mano no se pisa y deja de ser un issue.
    @Test func applierRespetaCamposEditados() {
        let movement = Movement(source: .card, direction: .outflow, amount: 0, occurredAt: capturedAt)
        movement.amount = Decimal(string: "7.50")!
        movement.editedFields = [.amount]
        ParseApplier.apply(
            CardInputParser.parse(CardRawInputs(merchant: "SUPER 99", amount: "0", cardName: "Visa")), to: movement)
        #expect(movement.amount == Decimal(string: "7.50")!)
        #expect(movement.parseIssues.isEmpty)
        #expect(movement.parseStatus == .ok)
    }
}
