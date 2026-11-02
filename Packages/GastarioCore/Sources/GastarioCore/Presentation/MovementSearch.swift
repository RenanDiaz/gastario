import Foundation

/// Búsqueda de la lista (SPEC Fase 4a, C19). Pura: la vista le pasa los campos de cada
/// movimiento, así se prueba sin SwiftData.
public struct MovementSearch: Equatable, Sendable {
    private static let locale = Locale(identifier: "es_PA")

    /// Términos ya normalizados (sin mayúsculas ni acentos).
    public let terms: [String]

    public init(text: String) {
        terms = text
            .split(whereSeparator: \.isWhitespace)
            .map { Self.fold(String($0)) }
    }

    /// Búsqueda vacía o solo espacios: no filtra nada.
    public var isEmpty: Bool { terms.isEmpty }

    /// Cada término tiene que aparecer en algún campo (Y), en cualquier orden. Un término
    /// numérico además coincide si el monto, con dos decimales y sin separador de miles,
    /// empieza con él. Un monto `0` (un `partial` que no se pudo leer) nunca coincide por monto.
    public func matches(fields: [String?], amount: Decimal) -> Bool {
        if terms.isEmpty { return true }
        let haystack = fields.compactMap { $0 }.map(Self.fold)
        let amountText = amount == 0 ? nil : Self.amountText(amount)
        return terms.allSatisfy { term in
            if haystack.contains(where: { $0.contains(term) }) { return true }
            if let amountText, let number = Self.numericTerm(term) {
                return amountText.hasPrefix(number)
            }
            return false
        }
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
    }

    /// `49`, `49.06`, `$4.5`: solo dígitos y a lo sumo un punto, con `$` opcional al inicio.
    /// Devuelve el término sin `$`, o `nil` si no es numérico.
    static func numericTerm(_ term: String) -> String? {
        let number = term.hasPrefix("$") ? String(term.dropFirst()) : term
        guard let first = number.first, first.isASCII, first.isNumber else { return nil }
        var dots = 0
        for character in number {
            if character == "." {
                dots += 1
            } else if !(character.isASCII && character.isNumber) {
                return nil
            }
        }
        return dots <= 1 ? number : nil
    }

    /// `49.06`, `1250.00`: el formato contra el que se compara el término numérico.
    static func amountText(_ amount: Decimal) -> String {
        amount.formatted(
            .number.precision(.fractionLength(2)).grouping(.never)
                .locale(Locale(identifier: "en_US_POSIX")))
    }
}
