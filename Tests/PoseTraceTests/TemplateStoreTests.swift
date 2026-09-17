import XCTest
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
