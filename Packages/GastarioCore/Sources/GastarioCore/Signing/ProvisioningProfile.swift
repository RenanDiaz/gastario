import Foundation

/// Lectura de `embedded.mobileprovision` (SPEC Fase 7b, C18). El archivo es un plist XML
/// envuelto en una firma CMS (DER); no hace falta interpretar la firma: el plist va completo y en
/// claro dentro de ella.
public enum ProvisioningProfile {
    private static let xmlStart = Data("<?xml".utf8)
    private static let plistEnd = Data("</plist>".utf8)

    /// `ExpirationDate` del perfil, o `nil` si no se encuentra el plist, no se puede leer o no
    /// trae esa fecha. Nunca lanza: el dato es solo informativo y la firma no se valida.
    public static func expirationDate(fromProfile data: Data) -> Date? {
        guard let start = data.range(of: xmlStart),
              let end = data.range(of: plistEnd, in: start.lowerBound..<data.endIndex)
        else { return nil }
        let xml = data.subdata(in: start.lowerBound..<end.upperBound)
        guard let plist = try? PropertyListSerialization.propertyList(from: xml, format: nil),
              let dictionary = plist as? [String: Any]
        else { return nil }
        return dictionary["ExpirationDate"] as? Date
    }
}
