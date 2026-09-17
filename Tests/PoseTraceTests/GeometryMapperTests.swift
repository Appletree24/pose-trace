import XCTest
@testable import PoseTrace

/// 坐标换算是回归重灾区(docs/03 §4),用例矩阵覆盖翻转/缩放/镜像/偏移
final class GeometryMapperTests: XCTestCase {

    func testImageSpaceFlipsYAndScalesXByAspect() {
        let p = GeometryMapper.imageSpacePoint(NormalizedPoint(x: 0.5, y: 0.25), aspect: 2)
        XCTAssertEqual(p.x, 1.0, accuracy: 1e-9)
        XCTAssertEqual(p.y, 0.75, accuracy: 1e-9)
    }

    func testBoundingBoxOfPoints() {
        let box = GeometryMapper.boundingBox(of: [
            CGPoint(x: 1, y: 2), CGPoint(x: -1, y: 5), CGPoint(x: 3, y: 3),
        ])
        XCTAssertEqual(box, CGRect(x: -1, y: 2, width: 4, height: 3))
    }

    func testBaseFitCentersPersonAndScalesTo70PercentHeight() {
        let bbox = CGRect(x: 0.2, y: 0.1, width: 0.4, height: 0.8)
        let viewSize = CGSize(width: 400, height: 800)
        let t = GeometryMapper.baseFitTransform(bbox: bbox, viewSize: viewSize)

        let center = CGPoint(x: bbox.midX, y: bbox.midY).applying(t)
        XCTAssertEqual(center.x, 200, accuracy: 1e-6)
        XCTAssertEqual(center.y, 400, accuracy: 1e-6)

        let top = CGPoint(x: bbox.midX, y: bbox.minY).applying(t)
        let bottom = CGPoint(x: bbox.midX, y: bbox.maxY).applying(t)
        XCTAssertEqual(bottom.y - top.y, 800 * 0.7, accuracy: 1e-6)
    }

    func testUserTransformMirrorReflectsAroundPivotX() {
        var user = OverlayTransform()
        user.mirrored = true
        let t = GeometryMapper.userTransform(user, pivot: CGPoint(x: 100, y: 100))
        let p = CGPoint(x: 130, y: 40).applying(t)
        XCTAssertEqual(p.x, 70, accuracy: 1e-6)
        XCTAssertEqual(p.y, 40, accuracy: 1e-6)
    }

    func testUserTransformOffsetAppliesAfterScale() {
        var user = OverlayTransform()
        user.scale = 2
        user.offsetX = 10
        user.offsetY = -5
        let t = GeometryMapper.userTransform(user, pivot: .zero)
        let p = CGPoint(x: 1, y: 1).applying(t)
        XCTAssertEqual(p.x, 12, accuracy: 1e-6)
        XCTAssertEqual(p.y, -3, accuracy: 1e-6)
    }

    func testUserTransformIdentityIsNoop() {
        let t = GeometryMapper.userTransform(.identity, pivot: CGPoint(x: 50, y: 50))
        let p = CGPoint(x: 12, y: 34).applying(t)
        XCTAssertEqual(p.x, 12, accuracy: 1e-6)
        XCTAssertEqual(p.y, 34, accuracy: 1e-6)
    }

    func testImageFitRectLetterboxesTallImageInSquareView() {
        let rect = GeometryMapper.imageFitRect(aspect: 0.5, in: CGSize(width: 400, height: 400))
        XCTAssertEqual(rect, CGRect(x: 100, y: 0, width: 200, height: 400))
    }

    func testImageFitRectLetterboxesWideImageInSquareView() {
        let rect = GeometryMapper.imageFitRect(aspect: 2, in: CGSize(width: 400, height: 400))
        XCTAssertEqual(rect, CGRect(x: 0, y: 100, width: 400, height: 200))
    }

    func testViewPointMapsCornersOfImageFit() {
        let fit = CGRect(x: 100, y: 0, width: 200, height: 400)
        // 归一化左下角 → 视图矩形左下角
        let bottomLeft = GeometryMapper.viewPoint(fromNormalized: NormalizedPoint(x: 0, y: 0), imageFit: fit)
        XCTAssertEqual(bottomLeft, CGPoint(x: 100, y: 400))
        // 归一化左上角 → 视图矩形左上角
        let topLeft = GeometryMapper.viewPoint(fromNormalized: NormalizedPoint(x: 0, y: 1), imageFit: fit)
        XCTAssertEqual(topLeft, CGPoint(x: 100, y: 0))
    }
}
