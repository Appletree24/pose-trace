import Foundation
import CoreGraphics
import Vision

/// 一个被检出的人物姿态候选
struct PoseCandidate {
    /// 置信度达标的关节点,key = Joint.rawValue,归一化坐标(左下原点)
    let joints: [String: NormalizedPoint]
    /// 平均置信度,用于候选排序
    let confidence: Double

    /// 完整姿势门槛:可用关节 < 8 判为"半身/质量不足"(docs/03 §2)
    var isLowQuality: Bool { joints.count < 8 }
}

/// 姿态提取的抽象口:未来切 Core AI 自选模型时新增实现,模板格式不变(docs/04 §5.1)
protocol PoseProviding {
    func detectPoses(in image: CGImage) throws -> [PoseCandidate]
}

/// Vision 实现(docs/03 §2)
struct VisionPoseProvider: PoseProviding {
    /// 关节置信度阈值;M0 用测试集校准(docs/03 §2)
    var confidenceThreshold: Float = 0.2

    func detectPoses(in image: CGImage) throws -> [PoseCandidate] {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])
        let observations = request.results ?? []
        return observations.compactMap { observation in
            guard let recognized = try? observation.recognizedPoints(.all) else { return nil }
            var joints: [String: NormalizedPoint] = [:]
            var confidenceSum = 0.0
            for (vnName, point) in recognized where point.confidence > confidenceThreshold {
                guard let joint = Joint.fromVision[vnName] else { continue }
                joints[joint.rawValue] = NormalizedPoint(
                    x: Double(point.location.x),
                    y: Double(point.location.y)
                )
                confidenceSum += Double(point.confidence)
            }
            guard !joints.isEmpty else { return nil }
            return PoseCandidate(joints: joints, confidence: confidenceSum / Double(joints.count))
        }
    }
}
