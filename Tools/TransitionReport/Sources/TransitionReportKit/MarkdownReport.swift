import Foundation

/// Tabla en Markdown para pegar en `docs/transition-report.md` (gate de la Fase 7).
public enum MarkdownReport {
    public static func render(_ comparison: Comparison) -> String {
        var lines: [String] = []
        let mismatchedDays = comparison.days.filter { !$0.matches }.count
        lines.append("## Comparación \(comparison.from) → \(comparison.to)")
        lines.append("")
        lines.append("- Días con movimientos: \(comparison.days.count); días que no cuadran: \(mismatchedDays).")
        lines.append("- Discrepancias fila por fila: \(comparison.discrepancies.count).")
        lines.append("- Filas del CSV viejo de Yappy sin tipo, confirmación ni monto: \(comparison.invalidOldRows.count).")
        lines.append("")
        lines.append("### Conteos y sumas por día")
        lines.append("")
        lines.append("Cada celda es `cantidad · suma` (salidas negativas).")
        lines.append("")
        lines.append("| Día | Tarjeta viejo | Tarjeta Gastario | Yappy viejo | Yappy Gastario | |")
        lines.append("|---|---:|---:|---:|---:|---|")
        for day in comparison.days {
            let cells = [Source.card, .yappy].flatMap { source in
                [cell(day.old[source]), cell(day.gastario[source])]
            }
            lines.append("| \(day.day) | " + cells.joined(separator: " | ") + " | \(day.matches ? "✅" : "❌") |")
        }

        lines.append("")
        lines.append("### Discrepancias")
        lines.append("")
        if comparison.discrepancies.isEmpty {
            lines.append("Ninguna: cada fila de un lado tiene su pareja en el otro.")
        } else {
            lines.append("La pista es una sugerencia; la clase (a)–(d) la decides tú ([`SPEC.md`, Fase 7](../SPEC.md#fase-7--transición-operativa)).")
            lines.append("")
            lines.append("| Fecha | Fuente | Qué pasa | Monto | Contraparte | Confirmación | Fila | Pista | Clase |")
            lines.append("|---|---|---|---:|---|---|---|---|---|")
            for item in comparison.discrepancies {
                let record = item.record
                var amount = money(record.amount)
                var origin = record.origin
                if let other = item.other {
                    amount += " vs " + money(other.amount)
                    origin += ", " + other.origin
                }
                let fields = [
                    timestamp(record.occurredAt), record.source.rawValue, item.kind.rawValue, amount,
                    escape(record.counterparty), record.confirmation ?? "", origin, item.hint, "",
                ]
                lines.append("| " + fields.joined(separator: " | ") + " |")
            }
        }

        if !comparison.invalidOldRows.isEmpty {
            lines.append("")
            lines.append("### Filas del CSV viejo de Yappy sin tipo, confirmación ni monto")
            lines.append("")
            lines.append("No cuentan en la tabla por día. Si alguna era un Yappy, búscalo en Gastario a mano.")
            lines.append("")
            for row in comparison.invalidOldRows {
                lines.append("- `\(row.origin)`: \(escape(row.summary))")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func cell(_ totals: Comparison.DayTotals?) -> String {
        guard let totals, totals.count > 0 else { return "—" }
        return "\(totals.count) · \(money(totals.sum))"
    }

    /// Dos decimales con punto, sin agrupar: igual que el export de Gastario.
    static func money(_ value: Decimal) -> String {
        var input = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &input, 2, .plain)
        let negative = rounded < 0
        let text = "\(negative ? -rounded : rounded)"
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        let decimals = parts.count > 1 ? String(parts[1]) : ""
        let padded = decimals.padding(toLength: 2, withPad: "0", startingAt: 0)
        return (negative ? "-" : "") + parts[0] + "." + padded
    }

    static func timestamp(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Day.timeZone
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return String(format: "%04d-%02d-%02d %02d:%02d", parts.year!, parts.month!, parts.day!, parts.hour!, parts.minute!)
    }

    /// `|` rompe la tabla de Markdown.
    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "|", with: "\\|")
    }
}
