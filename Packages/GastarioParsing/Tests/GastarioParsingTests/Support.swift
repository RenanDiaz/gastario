import Foundation

enum Fixture {
    /// Cuerpo de un fixture de `Fixtures/Yappy/`, tal cual (con BOM, HTML, U+00A0…).
    static func yappy(_ name: String) throws -> String {
        guard let base = Bundle.module.resourceURL else { throw FixtureError.missingBundle }
        let url = base.appendingPathComponent("Fixtures/Yappy/\(name)")
        return try String(contentsOf: url, encoding: .utf8)
    }

    enum FixtureError: Error { case missingBundle }
}

/// Fecha en hora de Panamá a partir de ISO 8601 con offset, por ejemplo `2026-10-07T11:53:00-05:00`.
func panama(_ iso: String) -> Date {
    ISO8601DateFormatter().date(from: iso)!
}

func decimal(_ text: String) -> Decimal {
    Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))!
}
