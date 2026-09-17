import Foundation
import CoreGraphics
import CoreVideo
import Vision

/// 人像分割:优先实例分割(多人可选),失败回退整体分割(docs/03 §3)
struct PersonSegmenter {

    struct InstanceScene {
        let observation: VNInstanceMaskObservation
        var instanceCount: Int { observation.allInstances.count }
    }

    /// 实例分割;检测不到人或请求失败时返回 nil(由上层决定回退,不抛错)
    func detectInstances(in image: CGImage) -> InstanceScene? {
        let request = VNGeneratePersonInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        guard (try? handler.perform([request])) != nil,
              let observation = request.results?.first,
              !observation.allInstances.isEmpty
        else { return nil }
        return InstanceScene(observation: observation)
    }

    /// 生成指定实例的 mask
    func mask(forInstance index: Int, in scene: InstanceScene) throws -> CVPixelBuffer {
        try scene.observation.generateMask(forInstances: IndexSet(integer: index))
    }

    /// 整体人像分割(兜底;多人时轮廓会包含所有人,属已知妥协)
    func wholePersonMask(in image: CGImage) throws -> CVPixelBuffer {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate   // 导入是一次性操作,用最高档(docs/03 §3)
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])
        guard let mask = request.results?.first?.pixelBuffer else { throw ExtractError.maskUnavailable }
        return mask
    }

    /// 姿态候选 → 实例编号:对每个关节在 instanceMask 采样,多数票(docs/03 §2)。
    /// 假设 instanceMask 为 8-bit 标签图(0 = 背景,1…N = 实例);格式不符返回 nil 走整体分割兜底。
    func instanceIndex(for candidate: PoseCandidate, in scene: InstanceScene) -> Int? {
        let mask = scene.observation.instanceMask
        guard CVPixelBufferGetPixelFormatType(mask) == kCVPixelFormatType_OneComponent8 else { return nil }
        guard CVPixelBufferLockBaseAddress(mask, .readOnly) == kCVReturnSuccess else { return nil }
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(mask) else { return nil }
        let width = CVPixelBufferGetWidth(mask)
        let height = CVPixelBufferGetHeight(mask)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(mask)
        guard width > 0, height > 0 else { return nil }

        var votes: [Int: Int] = [:]
        for point in candidate.joints.values {
            let x = min(max(Int(point.x * Double(width)), 0), width - 1)
            // 归一化左下原点 → 像素行左上原点
            let y = min(max(Int((1 - point.y) * Double(height)), 0), height - 1)
            let label = Int(base.load(fromByteOffset: y * bytesPerRow + x, as: UInt8.self))
            if label > 0 { votes[label, default: 0] += 1 }
        }
        return votes.max(by: { $0.value < $1.value })?.key
    }
}
