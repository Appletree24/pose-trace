import XCTest
@testable import PoseTrace

/// P2 打分器先行单测(docs/03 §7:接口现在就固定)
final class PoseComparatorTests: XCTestCase {

    /// 直立站姿(归一化坐标,左下原点、y 向上)
    private func standingPose() -> [String: NormalizedPoint] {
        var joints: [String: NormalizedPoint] = [:]
        func set(_ joint: Joint, _ x: Double, _ y: Double) {
            joints[joint.rawValue] = NormalizedPoint(x: x, y: y)
        }
        set(.nose, 0.50, 0.90)
        set(.neck, 0.50, 0.80)
        set(.root, 0.50, 0.50)
        set(.leftShoulder, 0.40, 0.78); set(.rightShoulder, 0.60, 0.78)
        set(.leftElbow, 0.35, 0.65); set(.rightElbow, 0.65, 0.65)
        set(.leftWrist, 0.33, 0.52); set(.rightWrist, 0.67, 0.52)
        set(.leftHip, 0.44, 0.50); set(.rightHip, 0.56, 0.50)
        set(.leftKnee, 0.44, 0.30); set(.rightKnee, 0.56, 0.30)
        set(.leftAnkle, 0.44, 0.10); set(.rightAnkle, 0.56, 0.10)
        return joints
    }

    func testIdenticalPoseScores100() {
        let pose = standingPose()
        let score = PoseComparator.score(reference: pose, live: pose)
        XCTAssertNotNil(score)
        XCTAssertEqual(score ?? 0, 100, accuracy: 0.001)
    }

    func testTranslatedAndScaledPoseStillScores100() {
        let pose = standingPose()
        var moved: [String: NormalizedPoint] = [:]
        for (key, p) in pose {
            moved[key] = NormalizedPoint(x: p.x * 0.5 + 0.2, y: p.y * 0.5 + 0.1)
        }
        let score = PoseComparator.score(reference: pose, live: moved)
        XCTAssertEqual(score ?? 0, 100, accuracy: 0.001)
    }

    func testRaisedArmLowersScore() {
        let pose = standingPose()
        var raised = pose
        // 左小臂从垂下改为举过头顶
        raised[Joint.leftElbow.rawValue] = NormalizedPoint(x: 0.35, y: 0.85)
        raised[Joint.leftWrist.rawValue] = NormalizedPoint(x: 0.30, y: 0.95)
        let score = PoseComparator.score(reference: pose, live: raised)
        XCTAssertNotNil(score)
        XCTAssertLessThan(score ?? 100, 95)
    }

    func testInsufficientJointsReturnsNil() {
        let pose = standingPose()
        let sparse = [Joint.nose.rawValue: NormalizedPoint(x: 0.5, y: 0.9)]
        XCTAssertNil(PoseComparator.score(reference: pose, live: sparse))
    }

    func testMirroredPoseScoresLowerThanIdentical() {
        // 非对称姿势:抬起右臂
        var reference = standingPose()
        reference[Joint.rightElbow.rawValue] = NormalizedPoint(x: 0.65, y: 0.85)
        reference[Joint.rightWrist.rawValue] = NormalizedPoint(x: 0.70, y: 0.95)
        // "镜像"的动作:抬左臂
        var mirrored = standingPose()
        mirrored[Joint.leftElbow.rawValue] = NormalizedPoint(x: 0.35, y: 0.85)
        mirrored[Joint.leftWrist.rawValue] = NormalizedPoint(x: 0.30, y: 0.95)

        let identical = PoseComparator.score(reference: reference, live: reference) ?? 0
        let flipped = PoseComparator.score(reference: reference, live: mirrored) ?? 0
        XCTAssertLessThan(flipped, identical)
    }
}
