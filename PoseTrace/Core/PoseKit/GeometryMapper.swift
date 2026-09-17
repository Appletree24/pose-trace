import Foundation
import CoreGraphics

/// 坐标换算的唯一入口(docs/02 D7、docs/03 §4)。三个坐标系:
/// - 归一化(存储/Core 层):左下原点,y 向上,x、y 取值 0…1
/// - 图像空间 imageSpace:左上原点,高度 = 1,宽度 = sourceAspect(消除纵横比畸变)
/// - 视图空间:SwiftUI 坐标,左上原点,pt
/// 全部为纯函数,单测覆盖见 Tests/GeometryMapperTests。
enum GeometryMapper {

    // MARK: 归一化 → 图像空间

    static func imageSpacePoint(_ p: NormalizedPoint, aspect: Double) -> CGPoint {
        CGPoint(x: p.x * aspect, y: 1 - p.y)
    }

    static func boundingBox(of points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .null }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for p in points.dropFirst() {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    // MARK: 相机叠加(初始摆放 + 用户变换)

    /// 初始摆放:人物包围盒缩放到视图高度的 heightRatio,中心对齐视图中心(docs/03 §5)
    static func baseFitTransform(bbox: CGRect, viewSize: CGSize, heightRatio: CGFloat = 0.7) -> CGAffineTransform {
        guard bbox.width > 0, bbox.height > 0, viewSize.height > 0 else { return .identity }
        let scale = viewSize.height * heightRatio / bbox.height
        let bboxCenter = CGPoint(x: bbox.midX, y: bbox.midY)
        let viewCenter = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        // 应用顺序(右起):平移到原点 → 缩放 → 平移到视图中心
        return CGAffineTransform.identity
            .translatedBy(x: viewCenter.x, y: viewCenter.y)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -bboxCenter.x, y: -bboxCenter.y)
    }

    /// 用户手势变换:绕 pivot 依次 镜像 → 旋转 → 等比缩放,最后整体平移
    static func userTransform(_ t: OverlayTransform, pivot: CGPoint) -> CGAffineTransform {
        let s = CGFloat(t.scale)
        // 应用顺序(右起):-pivot → 镜像 → 旋转 → 缩放 → +pivot
        let aroundPivot = CGAffineTransform.identity
            .translatedBy(x: pivot.x, y: pivot.y)
            .scaledBy(x: s, y: s)
            .rotated(by: CGFloat(t.rotationRadians))
            .scaledBy(x: t.mirrored ? -1 : 1, y: 1)
            .translatedBy(x: -pivot.x, y: -pivot.y)
        return aroundPivot.concatenating(
            CGAffineTransform(translationX: CGFloat(t.offsetX), y: CGFloat(t.offsetY))
        )
    }

    /// 完整变换:imageSpace → 视图。baseFit 把人物中心放到视图中心,该点即用户变换的 pivot
    static func composedTransform(personBBox: CGRect, viewSize: CGSize, user: OverlayTransform) -> CGAffineTransform {
        let base = baseFitTransform(bbox: personBBox, viewSize: viewSize)
        let pivot = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        return base.concatenating(userTransform(user, pivot: pivot))
    }

    // MARK: 提取预览(照片 aspect-fit 贴合)

    /// 整图 aspect-fit 后在视图内占据的矩形(与 SwiftUI scaledToFit 居中行为一致)
    static func imageFitRect(aspect: Double, in viewSize: CGSize) -> CGRect {
        guard aspect > 0, viewSize.width > 0, viewSize.height > 0 else { return .zero }
        let viewAspect = viewSize.width / viewSize.height
        if CGFloat(aspect) > viewAspect {
            let height = viewSize.width / CGFloat(aspect)
            return CGRect(x: 0, y: (viewSize.height - height) / 2, width: viewSize.width, height: height)
        } else {
            let width = viewSize.height * CGFloat(aspect)
            return CGRect(x: (viewSize.width - width) / 2, y: 0, width: width, height: viewSize.height)
        }
    }

    /// 归一化点 → 视图坐标(经 imageFitRect;含 y 翻转)
    static func viewPoint(fromNormalized p: NormalizedPoint, imageFit rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + CGFloat(p.x) * rect.width,
            y: rect.minY + (1 - CGFloat(p.y)) * rect.height
        )
    }
}
