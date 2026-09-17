import Foundation
import CoreGraphics

/// 模板持久化:templates.json + thumbnails/(docs/02 §3)。
/// 磁盘 IO 均为同步;写入走原子写。调用方决定执行环境(MVP 数据量小,主线程亦可接受)。
final class TemplateStore {
    private let thumbnailsDirectory: URL
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
        try FileManager.default.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
    }

    func load() -> [PoseTemplate] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // 损坏文件按空库处理,不阻塞使用(docs/04 §2 有损坏恢复用例)
        return (try? decoder.decode([PoseTemplate].self, from: data)) ?? []
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
}
