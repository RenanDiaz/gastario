import Foundation

public enum YappyDateParser {
    public static let timeZone = TimeZone(identifier: "America/Panama")!

    private static let months: [String: Int] = [
        "ene": 1, "feb": 2, "mar": 3, "abr": 4, "may": 5, "jun": 6, "jul": 7, "ago": 8,
        "sep": 9, "sept": 9, "oct": 10, "nov": 11, "dic": 12,
    ]

    /// Primera fecha con el formato de Yappy en el texto, por ejemplo `07 oct 2026 12:30 p. m.`,
    /// en hora de Panamá. Acepta espacios normales o no separables (U+00A0, U+202F).
    ///
    /// No usa `DateFormatter` con locale `es`: espera `a. m.` con espacios no separables y falla
    /// en silencio si el correo trae espacios normales, o al revés (`INTENT.md`).
    public static func parse(_ text: String) -> Date? {
        let normalized = TextNormalizer.normalize(text)
        let pattern = /(?i)(\d{1,2})\s+([a-z]{3,4})\.?\s+(\d{4})\s+(\d{1,2}):(\d{2})\s*([ap])\.?\s*m\.?/
        for match in normalized.matches(of: pattern) {
            guard
                let day = Int(match.output.1),
                let month = months[match.output.2.lowercased()],
                let year = Int(match.output.3),
                let hour12 = Int(match.output.4),
                let minute = Int(match.output.5),
                (1...12).contains(hour12), (0...59).contains(minute)
            else { continue }

            let isPM = match.output.6.lowercased() == "p"
            let hour = (hour12 % 12) + (isPM ? 12 : 0)

            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
            guard let date = calendar.date(from: components) else { continue }
            // Rechaza fechas que el calendario "corrige", como 31 sept → 1 oct.
            let check = calendar.dateComponents([.year, .month, .day], from: date)
            guard check.year == year, check.month == month, check.day == day else { continue }
            return date
        }
        return nil
    }
}
