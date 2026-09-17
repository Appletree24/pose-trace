import Foundation
import ImageIO
import CoreGraphics

enum ImageLoader {
    /// 解码 + EXIF 方向归一 + 降采样(长边 ≤ maxPixel),一步完成(docs/03 §1)。
    /// 返回 .up 方向的 CGImage,后续所有坐标不再关心 EXIF 方向。
    static func downsampledImage(from data: Data, maxPixel: Int = 2048) throws -> CGImage {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            throw ExtractError.imageDecodeFailed
        }
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // 应用 EXIF 方向
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ] as [CFString: Any] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            throw ExtractError.imageDecodeFailed
        }
        return image
    }
}
