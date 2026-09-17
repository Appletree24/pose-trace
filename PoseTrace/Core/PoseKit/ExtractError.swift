import Foundation

/// 提取管线统一错误;文案对照 docs/03 §6
enum ExtractError: Error, LocalizedError {
    case imageDecodeFailed
    case noPerson
    case lowQuality(jointCount: Int)
    case noContour
    case maskUnavailable

    var errorDescription: String? {
        switch self {
        case .imageDecodeFailed:
            return "无法读取这张照片,换一张试试。"
        case .noPerson:
            return "没有识别到人物。换一张人物完整、清晰的照片试试。"
        case .lowQuality:
            return "只识别到部分身体,轮廓可能不完整。可以继续使用,或换一张全身照。"
        case .noContour:
            return "人物轮廓提取失败(背景太复杂或对比度低),已保留骨架线可用。"
        case .maskUnavailable:
            return "人像分割不可用,已保留骨架线可用。"
        }
    }
}
