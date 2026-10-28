import Foundation

public enum YappyEmailParser {
    /// Parsea el cuerpo de un correo de Yappy, en HTML (lo que entrega `Content` en Shortcuts)
    /// o en texto plano.
    ///
    /// Estado (SPEC Fase 1):
    /// - `failed`: no se pudo determinar la dirección o el monto;
    /// - `partial`: falta alguno de contraparte, confirmación o fecha;
    /// - `ok`: todo presente. Un mensaje vacío no es un issue.
    public static func parse(_ content: String) -> ParsedYappy {
        let text = TextNormalizer.normalize(HTMLText.plainText(from: content))
        let lines = text
            .split(separator: "\n")
            .map { collapseSpaces($0) }
            .filter { !$0.isEmpty }

        let detected = detectKind(in: lines)
        let body = detected.map { Array(lines[($0.index + 1)...]) } ?? lines

        var result = ParsedYappy(
            kind: detected?.kind,
            amount: amount(in: body),
            counterparty: nil,
            message: "",
            confirmation: text.firstMatch(of: /[A-Z]{5}-\d{8}/).map { String($0.output) },
            occurredAt: YappyDateParser.parse(text),
            status: .ok,
            issues: []
        )

        switch detected?.kind {
        case .sent?:
            result.counterparty = value(after: "Enviado a", in: body)
            result.message = message(in: body)
        case .received?:
            result.counterparty = value(after: "Enviado por", in: body)
            result.message = message(in: body)
        case .paid?:
            result.counterparty = value(after: "Pagado a", in: body)
            result.message = message(in: body)
        case .commercialReceived?, .commercialOnlinePurchase?:
            result.counterparty = field("Cliente", in: body)
            if let comment = field("Comentario", in: body) {
                result.message = comment
            } else if let order = field("Número de pedido", in: body) {
                result.message = "Pedido \(order)"
            }
        case nil:
            break
        }

        if result.kind == nil { result.issues.insert(.direction) }
        if result.amount == nil { result.issues.insert(.amount) }
        if result.counterparty == nil { result.issues.insert(.counterparty) }
        if result.confirmation == nil { result.issues.insert(.confirmation) }
        if result.occurredAt == nil { result.issues.insert(.occurredAt) }

        if result.kind == nil || result.amount == nil {
            result.status = .failed
        } else if !result.issues.isEmpty {
            result.status = .partial
        }
        return result
    }

    // MARK: - Reglas

    /// Desde octubre de 2026 Yappy escribe "Enviaste con Yappy" en vez de "Enviaste por Yappy";
    /// se aceptan ambas preposiciones en los correos de persona a persona.
    private static func detectKind(in lines: [String]) -> (kind: YappyKind, index: Int)? {
        for (index, line) in lines.enumerated() {
            if line.starts(with: /Enviaste (por|con) Yappy/) { return (.sent, index) }
            if line.starts(with: /Te enviaron (por|con) Yappy/) { return (.received, index) }
            if line.starts(with: /Pagaste (por|con) Yappy/) { return (.paid, index) }
            if line.contains("ha recibido un pago por Yappy") { return (.commercialReceived, index) }
            if line.hasPrefix("Recibiste una compra en línea por Yappy") {
                return (.commercialOnlinePurchase, index)
            }
        }
        return nil
    }

    /// Número después del primer `$`.
    private static func amount(in lines: [String]) -> Decimal? {
        for line in lines {
            if let match = line.firstMatch(of: /\$\s*(\d[\d,]*(?:\.\d+)?)/) {
                return AmountParser.parse(String(match.output.1))
            }
        }
        return nil
    }

    /// Primera línea no vacía después de la línea `label`.
    private static func value(after label: String, in lines: [String]) -> String? {
        guard let index = lines.firstIndex(of: label), index + 1 < lines.count else { return nil }
        return lines[index + 1]
    }

    /// Primera línea después de `Mensaje`, salvo que sea otra etiqueta (entonces vacío).
    private static func message(in lines: [String]) -> String {
        guard let next = value(after: "Mensaje", in: lines) else { return "" }
        return ["Confirmación", "Fecha"].contains(next) ? "" : next
    }

    /// Valor de una línea `Etiqueta: valor` (Yappy Comercial). `nil` si falta o está vacío.
    private static func field(_ label: String, in lines: [String]) -> String? {
        let prefix = label + ":"
        guard let line = lines.first(where: { $0.hasPrefix(prefix) }) else { return nil }
        let value = line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    private static func collapseSpaces(_ line: Substring) -> String {
        line.replacing(/[ \t]+/, with: " ").trimmingCharacters(in: .whitespaces)
    }
}
