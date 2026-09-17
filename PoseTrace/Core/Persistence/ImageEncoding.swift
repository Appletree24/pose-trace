import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

/// CGImage 编码工具(ImageIO 实现,Core 层不引 UIKit,docs/02 §2)
enum ImageEncoding {
    static func jpegData(_ image: CGImage, quality: Double = 0.85) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }
        let options = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        CGImageDestinationAddImage(destination, image, options)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    /// 生成长边 ≤ maxPixel 的缩略图(经 JPEG 往返复用 ImageLoader 的降采样)
    static func thumbnail(of image: CGImage, maxPixel: Int = 600) -> CGImage? {
        guard let data = jpegData(image, quality: 0.9) else { return nil }
        return try? ImageLoader.downsampledImage(from: data, maxPixel: maxPixel)
    }
}
