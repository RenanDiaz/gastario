import Foundation
import Testing
@testable import GastarioParsing

struct AmountParserTests {
    /// Tabla de montos de `INTENT.md` (AC-2).
    @Test(arguments: [
        ("$3.80", "3.80"),
        ("$1,250.00", "1250.00"),
        ("B/.3.80", "3.80"),
        ("USD 3.80", "3.80"),
        ("$0.00", "0"),
    ])
    func montosConFormato(input: String, expected: String) {
        #expect(AmountParser.parse(input) == decimal(expected))
    }

    @Test func vacioONoParseableEsNil() {
        #expect(AmountParser.parse("") == nil)
        #expect(AmountParser.parse(nil) == nil)
        #expect(AmountParser.parse("sin monto") == nil)
    }
}

struct CardInputParserTests {
    @Test func capturaCompletaEsOk() {
        let parsed = CardInputParser.parse(CardRawInputs(
            merchant: "SUPER 99", amount: "$1,250.00", cardName: "Visa", city: "Panamá",
            latitude: 8.98, longitude: -79.52))
        #expect(parsed.amount == decimal("1250"))
        #expect(parsed.counterparty == "SUPER 99")
        #expect(parsed.cardName == "Visa")
        #expect(parsed.city == "Panamá")
        #expect(parsed.status == .ok)
        #expect(parsed.issues.isEmpty)
    }

    /// AC-12: Wallet entrega `Amount = 0` o vacío.
    @Test(arguments: ["0", "$0.00", "", "   "])
    func montoCeroOVacioEsPartial(amount: String) {
        let parsed = CardInputParser.parse(CardRawInputs(merchant: "SUPER 99", amount: amount, cardName: "Visa"))
        #expect(parsed.amount == 0)
        #expect(parsed.status == .partial)
        #expect(parsed.issues == [.amount])
    }

    /// AC-12: Wallet entrega `Merchant` vacío.
    @Test(arguments: ["", "  ", "\u{00A0}"])
    func merchantVacioEsPartial(merchant: String) {
        let parsed = CardInputParser.parse(CardRawInputs(merchant: merchant, amount: "$3.80", cardName: "Visa"))
        #expect(parsed.counterparty == nil)
        #expect(parsed.status == .partial)
        #expect(parsed.issues == [.counterparty])
    }

    /// AC-10: sin ubicación se guarda igual.
    @Test func sinUbicacionEsOk() {
        let parsed = CardInputParser.parse(CardRawInputs(merchant: "SUPER 99", amount: "3.80", cardName: "Visa", city: ""))
        #expect(parsed.city == nil)
        #expect(parsed.latitude == nil)
        #expect(parsed.status == .ok)
    }
}
