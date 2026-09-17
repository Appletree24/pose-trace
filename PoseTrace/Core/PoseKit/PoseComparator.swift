import Foundation

/// P2 实时匹配的纯函数打分器(docs/03 §7)。MVP 不接线,仅由单测保证可用;
/// P2 时把相机帧的检测结果喂给 score(reference:live:) 即可。
enum PoseComparator {

    /// 姿势相似度 0–100;nil 表示可比较肢体不足。
    /// 只比较骨骼向量方向(平移、尺度天然无关),权重见 Skeleton.scoredBones。
    static func score(
        reference: [String: NormalizedPoint],
        live: [String: NormalizedPoint],
        minBones: Int = 6
    ) -> Double? {
        var weightedSum = 0.0
        var totalWeight = 0.0
        var comparedBones = 0
        for bone in Skeleton.scoredBones {
            guard
                let ra = reference[bone.from.rawValue], let rb = reference[bone.to.rawValue],
                let la = live[bone.from.rawValue], let lb = live[bone.to.rawValue],
                let rv = normalized(dx: rb.x - ra.x, dy: rb.y - ra.y),
                let lv = normalized(dx: lb.x - la.x, dy: lb.y - la.y)
            else { continue }
            let cosine = rv.dx * lv.dx + rv.dy * lv.dy
            weightedSum += bone.weight * cosine
            totalWeight += bone.weight
            comparedBones += 1
        }
        guard comparedBones >= minBones, totalWeight > 0 else { return nil }
        let mean = weightedSum / totalWeight          // -1 … 1
        return min(100, max(0, (mean + 1) / 2 * 100))
    }

    private static func normalized(dx: Double, dy: Double) -> (dx: Double, dy: Double)? {
        let length = (dx * dx + dy * dy).squareRoot()
        guard length > 1e-6 else { return nil }
        return (dx / length, dy / length)
    }
}
