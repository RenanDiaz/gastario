import Testing
@testable import GastarioParsing

struct TextNormalizerTests {
    @Test func espaciosNoSeparablesPasanAEspacio() {
        #expect(TextNormalizer.normalize("08:31 a.\u{00A0}m.") == "08:31 a. m.")
        #expect(TextNormalizer.normalize("08:31 a.\u{202F}m.") == "08:31 a. m.")
    }

    @Test func saltosDeLineaUnificados() {
        #expect(TextNormalizer.normalize("a\r\nb\rc\u{2028}d\u{2029}e") == "a\nb\nc\nd\ne")
    }

    @Test func quitaBOM() {
        #expect(TextNormalizer.normalize("\u{FEFF}Hola") == "Hola")
    }
}

struct HTMLTextTests {
    @Test func textoPlanoNoCambia() {
        let text = "Enviaste por Yappy\n$40.00"
        #expect(HTMLText.plainText(from: text) == text)
    }

    @Test func etiquetasEnLineaNoCortanLaLinea() {
        let html = "<html><body><p><strong>Ana</strong><strong>\n   Morales</strong></p><br><p>Fecha</p></body></html>"
        #expect(HTMLText.plainText(from: html) == "Ana Morales\nFecha")
    }

    @Test func quitaHeadEstilosYComentarios() {
        let html = "<!DOCTYPE html><html><head><title>x</title><style>p{}</style></head><body><!-- nada --><div>Hola</div></body></html>"
        #expect(HTMLText.plainText(from: html) == "Hola")
    }

    @Test func decodificaEntidades() {
        let html = "<html><body><p>Confirmaci&oacute;n &amp; m&#225;s&nbsp;&#x41;</p></body></html>"
        #expect(HTMLText.plainText(from: html) == "Confirmación & más\u{00A0}A")
    }
}
