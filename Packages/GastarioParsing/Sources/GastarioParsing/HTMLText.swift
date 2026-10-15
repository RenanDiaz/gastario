import Foundation

/// Convierte HTML de correo a texto plano, una línea por bloque, como lo mostraría un navegador.
///
/// `NSAttributedString` con HTML no existe en Linux y en iOS necesita el hilo principal,
/// así que se hace a mano: es suficiente para el HTML de Yappy y no depende de WebKit.
public enum HTMLText {
    /// Etiquetas que en el render empiezan otra línea. El resto (`strong`, `span`, `a`, `img`…)
    /// se quita sin cortar la línea: "<strong>Ana</strong><strong> Morales</strong>" → "Ana Morales".
    private static let blockTags: Set<String> = [
        "address", "article", "blockquote", "br", "center", "div", "footer", "h1", "h2", "h3",
        "h4", "h5", "h6", "header", "hr", "li", "ol", "p", "section", "table", "tbody", "td",
        "tfoot", "th", "thead", "tr", "ul",
    ]

    private static let namedEntities: [String: String] = [
        "nbsp": "\u{00A0}", "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
        "copy": "©", "iexcl": "¡", "iquest": "¿",
        "aacute": "á", "eacute": "é", "iacute": "í", "oacute": "ó", "uacute": "ú", "ntilde": "ñ",
        "Aacute": "Á", "Eacute": "É", "Iacute": "Í", "Oacute": "Ó", "Uacute": "Ú", "Ntilde": "Ñ",
        "uuml": "ü", "Uuml": "Ü",
    ]

    /// `true` si el texto parece un documento HTML y no texto plano.
    public static func looksLikeHTML(_ text: String) -> Bool {
        let head = text.prefix(2048).lowercased()
        return head.contains("<!doctype html") || head.contains("<html") || head.contains("<body")
    }

    /// Devuelve el texto visible si `text` es HTML; si no, lo devuelve sin cambios.
    public static func plainText(from text: String) -> String {
        guard looksLikeHTML(text) else { return text }

        var html = text.replacingOccurrences(of: "\u{FEFF}", with: "")
        html = html.replacing(/(?s)<!--.*?-->/, with: "")
        html = html.replacing(/<![^>]*>/, with: "")
        html = html.replacing(/(?is)<(head|style|script|title)\b[^>]*>.*?<\/\1\s*>/, with: "")
        // Espacio en blanco del fuente HTML: colapsa como en el render (no incluye U+00A0).
        html = html.replacing(/[ \t\r\n\f]+/, with: " ")
        html = html.replacing(/<\s*(\/?)\s*([A-Za-z][A-Za-z0-9]*)[^>]*>/) { match in
            blockTags.contains(match.output.2.lowercased()) ? "\n" : ""
        }
        html = decodeEntities(html)

        var lines: [Substring] = []
        for line in html.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmed = line.trimmingCharacters(in: CharacterSet(charactersIn: " "))
            if !trimmed.isEmpty { lines.append(Substring(trimmed)) }
        }
        return lines.joined(separator: "\n")
    }

    private static func decodeEntities(_ text: String) -> String {
        text.replacing(/&(#[0-9]+|#[xX][0-9A-Fa-f]+|[A-Za-z]+);/) { match in
            let name = match.output.1
            if name.hasPrefix("#x") || name.hasPrefix("#X") {
                if let value = UInt32(name.dropFirst(2), radix: 16), let scalar = Unicode.Scalar(value) {
                    return String(Character(scalar))
                }
            } else if name.hasPrefix("#") {
                if let value = UInt32(name.dropFirst()), let scalar = Unicode.Scalar(value) {
                    return String(Character(scalar))
                }
            } else if let decoded = namedEntities[String(name)] {
                return decoded
            }
            return String(match.output.0)
        }
    }
}
