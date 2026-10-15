import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Fotos como JPEG calidad 0.8 con el lado mayor en 2048 px como máximo (SPEC §2, C8). Aplica la
/// orientación EXIF y nunca agranda una imagen más chica. Los PDFs no pasan por aquí.
public enum ImageCompressor {
    public static let maxPixelSize = 2048
    public static let quality = 0.8

    /// `nil` si `data` no es una imagen.
    public static func jpegData(from data: Data, maxPixelSize: Int = maxPixelSize, quality: Double = quality) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? maxPixelSize
        let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? maxPixelSize
        let longest = min(maxPixelSize, max(width, height))

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: longest,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(
            destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
