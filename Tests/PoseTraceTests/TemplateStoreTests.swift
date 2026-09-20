import XCTest
import Foundation
import CoreGraphics
@testable import PoseTrace

final class TemplateStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PoseTraceTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testSaveLoadRoundtrip() throws {
        let store = try TemplateStore(directory: directory)
        let template = PoseTemplate(
            id: UUID(),
            name: "测试姿势",
            createdAt: Date(),
            joints: [
                Joint.nose.rawValue: NormalizedPoint(x: 0.5, y: 0.9),
                Joint.neck.rawValue: NormalizedPoint(x: 0.5, y: 0.8),
            ],
            contour: [
                NormalizedPoint(x: 0.1, y: 0.1),
                NormalizedPoint(x: 0.9, y: 0.1),
                NormalizedPoint(x: 0.5, y: 0.9),
            ],
            sourceAspect: 0.75,
            thumbnailFile: "t.jpg"
        )
        try store.save([template])

        // 新实例重新读盘,验证完整往返
        let reloaded = try TemplateStore(directory: directory).load()
        XCTAssertEqual(reloaded.count, 1)
        XCTAssertEqual(reloaded[0].id, template.id)
        XCTAssertEqual(reloaded[0].name, "测试姿势")
        XCTAssertEqual(reloaded[0].contour.count, 3)
        XCTAssertEqual(reloaded[0].sourceAspect, 0.75, accuracy: 1e-9)
        XCTAssertEqual(reloaded[0].joints[Joint.nose.rawValue]?.x ?? -1, 0.5, accuracy: 1e-9)
        XCTAssertEqual(reloaded[0].joints[Joint.nose.rawValue]?.y ?? -1, 0.9, accuracy: 1e-9)
    }

    /// 新增字段(originalFile / isFavorite)随 JSON 往返(docs/01 P1)
    func testFavoriteAndOriginalRoundtrip() throws {
        let store = try TemplateStore(directory: directory)
        var template = Self.makeTemplate()
        template.isFavorite = true
        template.originalFile = "orig-abc.jpg"
        try store.save([template])

        let reloaded = try TemplateStore(directory: directory).load()
        XCTAssertEqual(reloaded.first?.isFavorite, true)
        XCTAssertEqual(reloaded.first?.originalFile, "orig-abc.jpg")
    }

    /// 旧版本 JSON(无 originalFile/isFavorite)可解码,字段落默认(docs/02 §3 兼容)
    func testLegacyTemplateDecodesWithDefaults() throws {
        let store = try TemplateStore(directory: directory)
        let legacyJSON = """
        [{
            "id": "00000000-0000-0000-0000-000000000001",
            "name": "旧版模板",
            "createdAt": "2026-09-20T10:00:00Z",
            "joints": {},
            "contour": [],
            "sourceAspect": 0.75,
            "thumbnailFile": "t.jpg"
        }]
        """
        try Data(legacyJSON.utf8).write(to: directory.appendingPathComponent("templates.json"))

        let loaded = store.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].name, "旧版模板")
        XCTAssertFalse(loaded[0].isFavorite)
        XCTAssertNil(loaded[0].originalFile)
    }

    /// 幽灵模式原图写/读/删闭环(docs/01 P1)
    func testOriginalImageRoundtrip() throws {
        let store = try TemplateStore(directory: directory)
        let image = Self.solidCGImage(width: 8, height: 8)
        try store.writeOriginal(image, named: "orig-test.jpg")

        XCTAssertNotNil(store.originalImage(named: "orig-test.jpg"))

        store.deleteOriginal(named: "orig-test.jpg")
        XCTAssertNil(store.originalImage(named: "orig-test.jpg"))
    }

    /// 原图文件缺失时返回 nil(幽灵按钮禁用条件)
    func testOriginalImageMissingReturnsNil() throws {
        let store = try TemplateStore(directory: directory)
        XCTAssertNil(store.originalImage(named: "nonexistent.jpg"))
    }

    /// 损坏 JSON 备份为 .corrupted-*,新读仍为空库(不丢现场)
    func testCorruptFileIsBackedUp() throws {
        let store = try TemplateStore(directory: directory)
        let file = directory.appendingPathComponent("templates.json")
        try Data("broken".utf8).write(to: file)

        _ = store.load()
        let backups = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.contains("corrupted-") }
        XCTAssertEqual(backups.count, 1)
    }

    // MARK: helpers

    private static func makeTemplate() -> PoseTemplate {
        PoseTemplate(
            id: UUID(),
            name: "fixture",
            createdAt: Date(),
            joints: [Joint.neck.rawValue: NormalizedPoint(x: 0.5, y: 0.8)],
            contour: [NormalizedPoint(x: 0.1, y: 0.1)],
            sourceAspect: 0.75,
            thumbnailFile: "t.jpg"
        )
    }

    private static func solidCGImage(width: Int, height: Int) -> CGImage {
        let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    func testCorruptFileLoadsAsEmptyLibrary() throws {
        let store = try TemplateStore(directory: directory)
        try Data("not json".utf8).write(to: directory.appendingPathComponent("templates.json"))
        XCTAssertTrue(store.load().isEmpty)
    }

    func testLoadWithoutFileReturnsEmpty() throws {
        let store = try TemplateStore(directory: directory)
        XCTAssertTrue(store.load().isEmpty)
    }
}
