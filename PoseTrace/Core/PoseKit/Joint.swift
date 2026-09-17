import Foundation
import Vision

/// 19 个关节点,与 Vision 的 VNHumanBodyPoseObservation 拓扑一一对应(docs/03 §2)。
/// rawValue 同时用作 PoseTemplate.joints 的持久化 key;更名即破坏已存模板,禁止改动。
enum Joint: String, Codable, CaseIterable, Sendable {
    case nose, leftEye, rightEye, leftEar, rightEar
    case neck, root
    case leftShoulder, rightShoulder
    case leftElbow, rightElbow, leftWrist, rightWrist
    case leftHip, rightHip
    case leftKnee, rightKnee, leftAnkle, rightAnkle
}

extension Joint {
    /// Vision 关节名 → 本项目关节;未来换姿态引擎(Core AI 等)时新增各自的映射表(docs/04 §5.1)
    static let fromVision: [VNHumanBodyPoseObservation.JointName: Joint] = [
        .nose: .nose, .leftEye: .leftEye, .rightEye: .rightEye,
        .leftEar: .leftEar, .rightEar: .rightEar,
        .neck: .neck, .root: .root,
        .leftShoulder: .leftShoulder, .rightShoulder: .rightShoulder,
        .leftElbow: .leftElbow, .rightElbow: .rightElbow,
        .leftWrist: .leftWrist, .rightWrist: .rightWrist,
        .leftHip: .leftHip, .rightHip: .rightHip,
        .leftKnee: .leftKnee, .rightKnee: .rightKnee,
        .leftAnkle: .leftAnkle, .rightAnkle: .rightAnkle,
    ]
}

/// 骨架拓扑:渲染连线与 P2 打分共用同一份定义(docs/03 §2)
enum Skeleton {
    /// 渲染用连线
    static let edges: [(Joint, Joint)] = [
        (.nose, .neck), (.nose, .leftEye), (.nose, .rightEye),
        (.leftEye, .leftEar), (.rightEye, .rightEar),
        (.neck, .leftShoulder), (.neck, .rightShoulder), (.neck, .root),
        (.root, .leftHip), (.root, .rightHip),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
    ]

    /// P2 匹配打分用的肢体向量与权重:四肢 > 躯干横向 > 头部(docs/03 §7)
    static let scoredBones: [(from: Joint, to: Joint, weight: Double)] = [
        (.neck, .root, 1.5),
        (.leftShoulder, .leftElbow, 1.2), (.leftElbow, .leftWrist, 1.2),
        (.rightShoulder, .rightElbow, 1.2), (.rightElbow, .rightWrist, 1.2),
        (.leftHip, .leftKnee, 1.2), (.leftKnee, .leftAnkle, 1.2),
        (.rightHip, .rightKnee, 1.2), (.rightKnee, .rightAnkle, 1.2),
        (.leftShoulder, .rightShoulder, 1.0), (.leftHip, .rightHip, 1.0),
        (.neck, .nose, 0.5),
    ]
}
