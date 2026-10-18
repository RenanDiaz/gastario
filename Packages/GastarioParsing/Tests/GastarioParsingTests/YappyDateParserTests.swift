import Foundation
import Testing
@testable import GastarioParsing

struct YappyDateParserTests {
    /// AC-16: espacio normal, U+00A0 o U+202F antes de "m.".
    @Test(arguments: [" ", "\u{00A0}", "\u{202F}"])
    func espaciosDistintos(space: String) {
        #expect(YappyDateParser.parse("04 oct 2026 08:31 a.\(space)m.") == panama("2026-10-04T08:31:00-05:00"))
    }

    @Test(arguments: [
        ("07 oct 2026 12:30 p. m.", "2026-10-07T12:30:00-05:00"),
        ("07 oct 2026 12:05 a. m.", "2026-10-07T00:05:00-05:00"),
        ("01 ago 2026 11:13 p. m.", "2026-08-01T23:13:00-05:00"),
        ("30 sept 2026 07:59 p. m.", "2026-09-30T19:59:00-05:00"),
        ("3 sep 2026 9:05 a. m.", "2026-09-03T09:05:00-05:00"),
        ("15 dic 2026 01:00 p. m.", "2026-12-15T13:00:00-05:00"),
    ])
    func formatos(input: String, expected: String) {
        #expect(YappyDateParser.parse(input) == panama(expected))
    }

    @Test(arguments: ["", "31 sept 2026 10:00 a. m.", "07 xyz 2026 10:00 a. m.", "07 oct 2026 13:00 p. m."])
    func invalidasSonNil(input: String) {
        #expect(YappyDateParser.parse(input) == nil)
    }
}
