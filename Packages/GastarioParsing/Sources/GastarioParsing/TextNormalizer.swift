import Foundation

public enum TextNormalizer {
    /// Normaliza el texto antes de cualquier regex:
    /// - U+00A0 y U+202F (espacios no separables) → espacio;
    /// - `\r\n` y `\r` → `\n`; U+2028 y U+2029 (separadores de línea y párrafo) → `\n`;
    /// - quita el BOM (U+FEFF).
    public static func normalize(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        var previousWasCR = false
        for scalar in text.unicodeScalars {
            defer { previousWasCR = scalar == "\r" }
            switch scalar.value {
            case 0x0D, 0x2028, 0x2029:
                scalars.append("\n")
            case 0x0A where previousWasCR:
                continue
            case 0xA0, 0x202F:
                scalars.append(" ")
            case 0xFEFF:
                continue
            default:
                scalars.append(scalar)
            }
        }
        return String(scalars)
    }
}
