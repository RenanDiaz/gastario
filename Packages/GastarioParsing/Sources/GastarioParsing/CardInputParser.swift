import Foundation

public enum CardInputParser {
    /// Datos vacíos de Wallet: monto vacío, no parseable o `0` → issue `amount` y `amount = 0`;
    /// merchant vacío → issue `counterparty`. Nunca descarta la captura.
    public static func parse(_ raw: CardRawInputs) -> ParsedCard {
        var issues: Set<ParseIssue> = []

        let amount: Decimal
        if let parsed = AmountParser.parse(TextNormalizer.normalize(raw.amount)), parsed != 0 {
            amount = parsed
        } else {
            amount = 0
            issues.insert(.amount)
        }

        let counterparty = nonEmpty(raw.merchant)
        if counterparty == nil { issues.insert(.counterparty) }

        return ParsedCard(
            amount: amount,
            counterparty: counterparty,
            cardName: nonEmpty(raw.cardName),
            city: raw.city.flatMap(nonEmpty),
            latitude: raw.latitude,
            longitude: raw.longitude,
            status: issues.isEmpty ? .ok : .partial,
            issues: issues
        )
    }

    private static func nonEmpty(_ text: String) -> String? {
        let trimmed = TextNormalizer.normalize(text).trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
