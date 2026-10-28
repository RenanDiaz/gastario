import Foundation
import Testing
@testable import GastarioParsing

/// Fixtures reales anonimizados. Los `.html` son lo que entrega `Content` en Shortcuts; los `.txt`
/// vienen de Mail en texto plano porque todavía no hay HTML de esos tipos (SPEC Fase 1).
struct YappyEmailParserTests {
    /// AC-3, AC-16 (U+00A0 real).
    @Test func enviadoConMensaje() throws {
        let parsed = YappyEmailParser.parse(try Fixture.yappy("sent-with-message.html"))
        #expect(parsed.kind == .sent)
        #expect(parsed.direction == .outflow)
        #expect(parsed.amount == decimal("600.00"))
        #expect(parsed.counterparty == "Ana Morales")
        #expect(parsed.message == "Deposito envio de Luis")
        #expect(parsed.confirmation == "KTRWA-10293847")
        #expect(parsed.occurredAt == panama("2026-10-07T11:53:00-05:00"))
        #expect(parsed.status == .ok)
        #expect(parsed.issues.isEmpty)
    }

    /// AC-4.
    @Test func enviadoSinMensaje() throws {
        let parsed = YappyEmailParser.parse(try Fixture.yappy("sent-without-message.html"))
        #expect(parsed.kind == .sent)
        #expect(parsed.amount == decimal("0.01"))
        #expect(parsed.counterparty == "Ana Morales")
        #expect(parsed.message == "")
        #expect(parsed.confirmation == "PLQZD-56473829")
        #expect(parsed.occurredAt == panama("2026-10-07T12:01:00-05:00"))
        #expect(parsed.status == .ok)
    }

    @Test func recibido() throws {
        let parsed = YappyEmailParser.parse(try Fixture.yappy("received.html"))
        #expect(parsed.kind == .received)
        #expect(parsed.direction == .inflow)
        #expect(parsed.amount == decimal("0.01"))
        #expect(parsed.counterparty == "Ana M.")
        #expect(parsed.message == "Devolucion")
        #expect(parsed.confirmation == "BVNHE-38291047")
        #expect(parsed.occurredAt == panama("2026-10-07T12:03:00-05:00"))
        #expect(parsed.status == .ok)
    }

    /// El mismo tipo de correo en texto plano da el mismo resultado que en HTML.
    @Test func enviadoEnTextoPlano() throws {
        let parsed = YappyEmailParser.parse(try Fixture.yappy("sent-as-text.txt"))
        #expect(parsed.kind == .sent)
        #expect(parsed.amount == decimal("40.00"))
        #expect(parsed.counterparty == "Luis Herrera")
        #expect(parsed.message == "Prestamo de SL para cuerdas")
        #expect(parsed.confirmation == "RTYUI-22334455")
        #expect(parsed.occurredAt == panama("2026-10-07T12:30:00-05:00"))
        #expect(parsed.status == .ok)
    }

    /// Formato de octubre de 2026: "Enviaste con Yappy" en vez de "por".
    @Test func enviadoConYappy() throws {
        let parsed = YappyEmailParser.parse(try Fixture.yappy("sent-con-yappy.txt"))
        #expect(parsed.kind == .sent)
        #expect(parsed.amount == decimal("15.00"))
        #expect(parsed.counterparty == "Marta Quintero")
        #expect(parsed.message == "Para pagar el estudio")
        #expect(parsed.confirmation == "QWERT-55667788")
        #expect(parsed.occurredAt == panama("2026-10-27T19:21:00-05:00"))
        #expect(parsed.status == .ok)
    }

    /// Todavía no hay correos reales de "Te enviaron con" ni "Pagaste con"; se asume el mismo cambio.
    @Test("Encabezados con \"con Yappy\" SYNTHETIC", arguments: [
        ("Te enviaron con Yappy", YappyKind.received),
        ("Pagaste con Yappy", YappyKind.paid),
    ])
    func encabezadosConYappy(header: String, kind: YappyKind) {
        #expect(YappyEmailParser.parse("\(header)\n$5.00").kind == kind)
    }

    @Test func pagoAComercio() throws {
        let parsed = YappyEmailParser.parse(try Fixture.yappy("paid-merchant.txt"))
        #expect(parsed.kind == .paid)
        #expect(parsed.direction == .outflow)
        #expect(parsed.amount == decimal("0.21"))
        #expect(parsed.counterparty == "FARMACIA EJEMPLO")
        #expect(parsed.message == "")
        #expect(parsed.confirmation == "ZXCVB-11223344")
        #expect(parsed.occurredAt == panama("2026-10-07T08:46:00-05:00"))
        #expect(parsed.status == .ok)
    }

    @Test func pagoAComercioConMensaje() throws {
        let parsed = YappyEmailParser.parse(try Fixture.yappy("paid-merchant-with-message.txt"))
        #expect(parsed.kind == .paid)
        #expect(parsed.amount == decimal("10.11"))
        #expect(parsed.counterparty == "Venta de Entradas")
        #expect(parsed.message == "Por pedido ABCD1234EFGH")
        #expect(parsed.confirmation == "MNBVC-99887766")
        #expect(parsed.occurredAt == panama("2026-09-30T19:59:00-05:00"))
        #expect(parsed.status == .ok)
    }

    /// Cuerpo real tal como llegó al intent (`Content` en texto plano, copiado de la vista de
    /// cuerpo crudo). Cierra la comparación de fixtures de la Fase 4.
    @Test func pagoAComercioContentReal() throws {
        let parsed = YappyEmailParser.parse(try Fixture.yappy("paid-merchant-content.txt"))
        #expect(parsed.kind == .paid)
        #expect(parsed.direction == .outflow)
        #expect(parsed.amount == decimal("49.06"))
        #expect(parsed.counterparty == "ASEGURADORA EJEMPLO")
        #expect(parsed.message == "Por pedido 512340")
        #expect(parsed.confirmation == "LKJHG-24681357")
        #expect(parsed.occurredAt == panama("2026-10-15T12:50:00-05:00"))
        #expect(parsed.status == .ok)
    }

    @Test func comercialRecibido() throws {
        let parsed = YappyEmailParser.parse(try Fixture.yappy("commercial-received.txt"))
        #expect(parsed.kind == .commercialReceived)
        #expect(parsed.direction == .inflow)
        #expect(parsed.amount == decimal("20.00"))
        #expect(parsed.counterparty == "Jorge Rios")
        #expect(parsed.message == "")
        #expect(parsed.confirmation == "QWERT-44556677")
        #expect(parsed.occurredAt == panama("2026-08-01T23:13:00-05:00"))
        #expect(parsed.status == .ok)
    }

    /// Mismo pago que `paid-merchant-with-message.txt`, visto desde el negocio: misma
    /// confirmación, dirección opuesta. La deduplicación de la Fase 2 debe conservar ambos.
    @Test func comercialCompraEnLinea() throws {
        let parsed = YappyEmailParser.parse(try Fixture.yappy("commercial-online-purchase.txt"))
        #expect(parsed.kind == .commercialOnlinePurchase)
        #expect(parsed.direction == .inflow)
        #expect(parsed.amount == decimal("10.11"))
        #expect(parsed.counterparty == "Pedro Gomez")
        #expect(parsed.message == "Pedido ABCD1234EFGH")
        #expect(parsed.confirmation == "MNBVC-99887766")
        #expect(parsed.occurredAt == panama("2026-09-30T19:59:00-05:00"))
        #expect(parsed.status == .ok)
    }

    @Test("Monto con coma SYNTHETIC")
    func montoConComa() throws {
        let parsed = YappyEmailParser.parse(try Fixture.yappy("amount-with-comma.html"))
        #expect(parsed.amount == decimal("1250.00"))
        #expect(parsed.status == .ok)
    }

    /// AC-16. La variante con U+00A0 es la de los fixtures reales.
    @Test("Fecha con U+202F y con espacio normal SYNTHETIC", arguments: ["date-narrow-nbsp.html", "date-plain.html"])
    func variantesDeFecha(name: String) throws {
        let parsed = YappyEmailParser.parse(try Fixture.yappy(name))
        #expect(parsed.occurredAt == panama("2026-10-07T11:53:00-05:00"))
        #expect(parsed.status == .ok)
    }

    /// AC-7 (mitad de parseo).
    @Test func formatoInesperadoEsFailed() throws {
        let parsed = YappyEmailParser.parse(try Fixture.yappy("unexpected-format.txt"))
        #expect(parsed.kind == nil)
        #expect(parsed.status == .failed)
        #expect(parsed.issues.isSuperset(of: [.direction, .amount]))
    }

    @Test func sinMontoEsFailed() {
        let parsed = YappyEmailParser.parse("Enviaste por Yappy\nEnviado a\nAna Morales\nConfirmación\nKTRWA-10293847")
        #expect(parsed.kind == .sent)
        #expect(parsed.status == .failed)
        #expect(parsed.issues.contains(.amount))
    }

    @Test func faltanCamposEsPartial() {
        let parsed = YappyEmailParser.parse("Enviaste por Yappy\n$5.00\nEnviado a\nAna Morales\nFecha\nayer")
        #expect(parsed.status == .partial)
        #expect(parsed.issues == [.confirmation, .occurredAt])
    }
}
