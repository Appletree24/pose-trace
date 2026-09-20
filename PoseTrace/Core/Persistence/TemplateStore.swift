import Foundation
import CoreGraphics

/// 模板持久化:templates.json + thumbnails/ + originals/(幽灵模式参考图,docs/02 §3)。
/// 磁盘 IO 均为同步;写入走原子写。调用方决定执行环境(MVP 数据量小,主线程亦可接受)。
final class TemplateStore {
    private let thumbnailsDirectory: URL
    private let originalsDirectory: URL
    private let fileURL: URL

    /// - Parameter directory: 存储根目录;默认 Application Support/PoseTrace(测试传临时目录)
    init(directory: URL? = nil) throws {
        let base: URL
        if let directory {
            base = directory
        } else {
            base = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("PoseTrace", isDirectory: true)
        }
        thumbnailsDirectory = base.appendingPathComponent("thumbnails", isDirectory: true)
        fileURL = base.appendingPathComponent("templates.json")
        originalsDirectory = base.appendingPathComponent("originals", isDirectory: true)
        try FileManager.default.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: originalsDirectory, withIntermediateDirectories: true)
    }

    func load() -> [PoseTemplate] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // 损坏文件按空库处理并备份现场,便于定位问题(docs/04 §2 有损坏恢复用例)
        guard let decoded = try? decoder.decode([PoseTemplate].self, from: data) else {
            let backup = fileURL.deletingPathExtension()
                .appendingPathExtension("corrupted-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            return []
        }
        return decoded
    }

    func save(_ templates: [PoseTemplate]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(templates)
        try data.write(to: fileURL, options: .atomic)
    }

    func writeThumbnail(_ image: CGImage, named name: String) throws {
        guard let thumbnail = ImageEncoding.thumbnail(of: image, maxPixel: 600),
              let data = ImageEncoding.jpegData(thumbnail, quality: 0.85) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: thumbnailsDirectory.appendingPathComponent(name), options: .atomic)
    }

    func thumbnailURL(named name: String) -> URL {
        thumbnailsDirectory.appendingPathComponent(name)
    }

    func deleteThumbnail(named name: String) {
        try? FileManager.default.removeItem(at: thumbnailsDirectory.appendingPathComponent(name))
    }

    /// 参考原图落盘(幽灵模式用,docs/01 P1);长边 ≤ 2048 保持解码开销可控
    func writeOriginal(_ image: CGImage, named name: String) throws {
        guard let data = ImageEncoding.jpegData(image, quality: 0.9) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: originalsDirectory.appendingPathComponent(name), options: .atomic)
    }

    /// 读参考原图;文件缺失返回 nil(幽灵模式按钮据此禁用)
    func originalImage(named name: String) -> CGImage? {
        guard let data = try? Data(contentsOf: originalsDirectory.appendingPathComponent(name)) else {
            return nil
        }
        return try? ImageLoader.downsampledImage(from: data, maxPixel: 2048)
    }

    func deleteOriginal(named name: String) {
        try? FileManager.default.removeItem(at: originalsDirectory.appendingPathComponent(name))
    }
}
