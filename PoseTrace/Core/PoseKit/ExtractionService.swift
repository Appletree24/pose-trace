import Foundation
import CoreGraphics
import CoreVideo

/// 一次导入的分析产物
struct AnalyzedPhoto {
    /// 方向已归一、降采样后的图(供预览与缩略图复用)
    let image: CGImage
    /// 宽高比 w/h
    let aspect: Double
    /// 姿态候选,按平均置信度降序
    let candidates: [PoseCandidate]
    /// 实例分割场景;nil 表示实例分割不可用(走整体分割兜底)
    let instances: PersonSegmenter.InstanceScene?
}

/// 提取管线编排(docs/03 管线总览)。方法均为同步阻塞,调用方放后台任务执行。
struct ExtractionService {
    var poseProvider: PoseProviding = VisionPoseProvider()
    var segmenter = PersonSegmenter()
    var contourBuilder = ContourBuilder()

    func analyze(imageData: Data) throws -> AnalyzedPhoto {
        let image = try ImageLoader.downsampledImage(from: imageData, maxPixel: 2048)
        let candidates = try poseProvider.detectPoses(in: image)
            .sorted { $0.confidence > $1.confidence }
        guard !candidates.isEmpty else { throw ExtractError.noPerson }
        return AnalyzedPhoto(
            image: image,
            aspect: Double(image.width) / Double(image.height),
            candidates: candidates,
            instances: segmenter.detectInstances(in: image)
        )
    }

    /// 为选中的候选生成轮廓。失败返回空数组:骨架仍可用,UI 按 ExtractError.noContour 文案提示(docs/03 §6)
    func contour(for candidate: PoseCandidate, in photo: AnalyzedPhoto) -> [NormalizedPoint] {
        do {
            let mask: CVPixelBuffer
            if let scene = photo.instances,
               let index = segmenter.instanceIndex(for: candidate, in: scene) {
                mask = try segmenter.mask(forInstance: index, in: scene)
            } else {
                mask = try segmenter.wholePersonMask(in: photo.image)
            }
            return try contourBuilder.contour(from: mask)
        } catch {
            return []
        }
    }

    func makeTemplate(
        name: String,
        candidate: PoseCandidate,
        contour: [NormalizedPoint],
        photo: AnalyzedPhoto,
        thumbnailFile: String
    ) -> PoseTemplate {
        PoseTemplate(
            id: UUID(),
            name: name,
            createdAt: Date(),
            joints: candidate.joints,
            contour: contour,
            sourceAspect: photo.aspect,
            thumbnailFile: thumbnailFile
        )
    }
}
