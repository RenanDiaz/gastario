import Foundation

public enum AmountParser {
    /// Primer número del texto: `"$1,250.00"` → `1250.00`, `"B/.3.80"` → `3.80`, `"$0.00"` → `0`.
    /// Devuelve `nil` si está vacío o no hay número. No basta con quitar lo que no sea dígito o
    /// punto: `B/.3.80` quedaría `.3.80`.
    public static func parse(_ text: String?) -> Decimal? {
        guard let text, let match = text.firstMatch(of: /\d[\d,]*(?:\.\d+)?/) else { return nil }
        let digits = match.output.replacingOccurrences(of: ",", with: "")
        return Decimal(string: digits, locale: Locale(identifier: "en_US_POSIX"))
    }
}
