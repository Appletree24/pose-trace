import Foundation
import CoreGraphics

/// 归一化坐标点。全项目内部表示:Vision 归一化坐标,左下原点、y 向上(docs/02 D7)。
struct NormalizedPoint: Codable, Hashable, Sendable {
    var x: Double
    var y: Double
}

/// 姿势模板:一次成功提取的全部产物(docs/02 §3)。
struct PoseTemplate: Codable, Identifiable, Sendable {
    let id: UUID
    var name: String
    let createdAt: Date
    /// 置信度达标的关节点,key = Joint.rawValue(避免非 String key 字典的编码陷阱)
    let joints: [String: NormalizedPoint]
    /// 人物外轮廓多边形点串(已简化);渲染时做 Catmull-Rom 平滑。可为空(轮廓提取失败,仅骨架可用)
    let contour: [NormalizedPoint]
    /// 参考图宽高比 w/h,用于保持人物比例
    let sourceAspect: Double
    /// 缩略图文件名(TemplateStore.thumbnails/ 下)
    let thumbnailFile: String
    /// 参考原图文件名(TemplateStore/originals/ 下);nil = 未保留原图(幽灵模式不可用)
    var originalFile: String?
    /// 收藏;列表排序时置顶(docs/01 P1)
    var isFavorite: Bool = false

    func point(_ joint: Joint) -> NormalizedPoint? { joints[joint.rawValue] }

    /// 自定义解码器会抑制成员初始化器,显式补回
    init(
        id: UUID,
        name: String,
        createdAt: Date,
        joints: [String: NormalizedPoint],
        contour: [NormalizedPoint],
        sourceAspect: Double,
        thumbnailFile: String,
        originalFile: String? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.joints = joints
        self.contour = contour
        self.sourceAspect = sourceAspect
        self.thumbnailFile = thumbnailFile
        self.originalFile = originalFile
        self.isFavorite = isFavorite
    }

    /// 旧版本模板没有 originalFile/isFavorite,给默认值保证可解码(新增字段必须在此登记默认)
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        joints = try c.decode([String: NormalizedPoint].self, forKey: .joints)
        contour = try c.decode([NormalizedPoint].self, forKey: .contour)
        sourceAspect = try c.decode(Double.self, forKey: .sourceAspect)
        thumbnailFile = try c.decode(String.self, forKey: .thumbnailFile)
        originalFile = try c.decodeIfPresent(String.self, forKey: .originalFile)
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }
}

/// 相机闪光灯模式
enum FlashMode: String, Codable, CaseIterable, Sendable {
    case auto, on, off

    var next: FlashMode {
        switch self {
        case .auto: return .on
        case .on: return .off
        case .off: return .auto
        }
    }
}


/// 叠加层显示模式
enum OverlayStyle: String, Codable, CaseIterable, Sendable {
    case contour, skeleton, both

    var next: OverlayStyle {
        switch self {
        case .contour: return .skeleton
        case .skeleton: return .both
        case .both: return .contour
        }
    }
}

/// 相机页叠加变换,由手势驱动(docs/03 §5)。
/// 语义:初始摆放(GeometryMapper.baseFitTransform)之后,绕人物中心 镜像 → 旋转 → 缩放,最后平移 offset。
struct OverlayTransform: Codable, Sendable {
    var scale: Double = 1
    var rotationRadians: Double = 0
    var offsetX: Double = 0
    var offsetY: Double = 0
    var mirrored: Bool = false
    var opacity: Double = 0.6
    var style: OverlayStyle = .both

    static let identity = OverlayTransform()
}
