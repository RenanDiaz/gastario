import Foundation

/// Validación de links para adjuntos (SPEC Fase 6, C7).
public enum AttachmentRules {
    public static let qrNotALinkMessage = "El QR no contiene un link"

    /// Solo `http`/`https` con host. Rechaza `javascript:`, `ftp://`, texto plano.
    ///
    /// - Parameter allowMissingScheme: para links escritos a mano, `dgi-fep.mef.gob.pa/x` se
    ///   completa con `https://`. Para QR va en `false`: el payload tiene que ser un URL tal cual.
    public static func link(from text: String, allowMissingScheme: Bool = false) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace) else { return nil }
        if let url = httpURL(trimmed) { return url }
        guard allowMissingScheme, !trimmed.contains(":"), trimmed.contains(".") else { return nil }
        return httpURL("https://" + trimmed)
    }

    private static func httpURL(_ text: String) -> URL? {
        guard
            let url = URL(string: text),
            let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
            let host = url.host(), host.contains(".")
        else { return nil }
        return url
    }
}
