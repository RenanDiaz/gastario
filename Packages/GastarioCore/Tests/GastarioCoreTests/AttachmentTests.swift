import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import GastarioCore

struct AttachmentRulesTests {
    @Test(arguments: [
        "https://dgi-fep.mef.gob.pa/Consultas/FacturasPorQR?chFE=FE0120000",
        "http://example.com",
        "  https://example.com/x  ",
    ])
    func aceptaLinks(text: String) {
        #expect(AttachmentRules.link(from: text) != nil)
    }

    @Test(arguments: [
        "javascript:alert(1)", "ftp://example.com/archivo", "texto plano", "", "https://", "mailto:a@b.com",
        "dgi-fep.mef.gob.pa/x",
    ])
    func rechazaQR(text: String) {
        #expect(AttachmentRules.link(from: text) == nil)
    }

    @Test func linkEscritoSinEsquema() {
        #expect(AttachmentRules.link(from: "dgi-fep.mef.gob.pa/x", allowMissingScheme: true)?.absoluteString
            == "https://dgi-fep.mef.gob.pa/x")
        #expect(AttachmentRules.link(from: "hola", allowMissingScheme: true) == nil)
        #expect(AttachmentRules.link(from: "javascript:alert(1)", allowMissingScheme: true) == nil)
    }
}

struct ImageCompressorTests {
    func pngData(width: Int, height: Int) -> Data {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 0.9, green: 0.3, blue: 0.1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let output = NSMutableData()
        let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        CGImageDestinationFinalize(destination)
        return output as Data
    }

    func info(_ data: Data) -> (width: Int, height: Int, type: String?) {
        let source = CGImageSourceCreateWithData(data as CFData, nil)!
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as! [CFString: Any]
        return (
            properties[kCGImagePropertyPixelWidth] as! Int,
            properties[kCGImagePropertyPixelHeight] as! Int,
            CGImageSourceGetType(source) as String?)
    }

    /// C8: el lado mayor queda en 2048 y se conserva la proporción.
    @Test func reduceAlMaximo() throws {
        let jpeg = try #require(ImageCompressor.jpegData(from: pngData(width: 4000, height: 3000)))
        let result = info(jpeg)
        #expect(result.width == 2048)
        #expect(result.height == 1536)
        #expect(result.type == UTType.jpeg.identifier)
    }

    @Test func noAgrandaImagenesChicas() throws {
        let jpeg = try #require(ImageCompressor.jpegData(from: pngData(width: 800, height: 600)))
        let result = info(jpeg)
        #expect(result.width == 800)
        #expect(result.height == 600)
    }

    @Test func datosQueNoSonImagen() {
        #expect(ImageCompressor.jpegData(from: Data("no soy una imagen".utf8)) == nil)
    }
}
