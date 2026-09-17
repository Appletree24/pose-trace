import Foundation
import CoreGraphics

/// 模板几何 → 视图坐标 CGPath(纯 CoreGraphics,无 UI 依赖;绘制样式在 Features/Camera/OverlayDrawing)
enum OverlayRenderer {

    struct Paths {
        var contour: CGPath?
        var skeleton: CGPath?
        var jointDots: CGPath?
        static let empty = Paths()
    }

    // MARK: 相机页(初始摆放 + 用户变换,docs/03 §5)

    static func cameraPaths(template: PoseTemplate, user: OverlayTransform, viewSize: CGSize) -> Paths {
        let aspect = template.sourceAspect
        let contourPoints = template.contour.map { GeometryMapper.imageSpacePoint($0, aspect: aspect) }
        var joints: [Joint: CGPoint] = [:]
        for joint in Joint.allCases {
            if let p = template.point(joint) {
                joints[joint] = GeometryMapper.imageSpacePoint(p, aspect: aspect)
            }
        }
        let bbox = GeometryMapper.boundingBox(of: contourPoints + Array(joints.values))
        guard !bbox.isNull, bbox.width > 0, bbox.height > 0,
              viewSize.width > 0, viewSize.height > 0 else { return .empty }

        var transform = GeometryMapper.composedTransform(personBBox: bbox, viewSize: viewSize, user: user)
        let dotRadius = max(bbox.width, bbox.height) * 0.012   // 相对人物尺寸,随缩放一致
        return Paths(
            contour: smoothClosedPath(points: contourPoints)?.copy(using: &transform),
            skeleton: skeletonPath(joints: joints)?.copy(using: &transform),
            jointDots: jointDotsPath(joints: joints, radius: dotRadius)?.copy(using: &transform)
        )
    }

    // MARK: 提取预览页(贴合照片的 aspect-fit 映射,docs/03 §6)

    static func previewPaths(
        joints: [String: NormalizedPoint],
        contour: [NormalizedPoint],
        aspect: Double,
        viewSize: CGSize
    ) -> Paths {
        let fit = GeometryMapper.imageFitRect(aspect: aspect, in: viewSize)
        guard fit.width > 0, fit.height > 0 else { return .empty }
        let contourPoints = contour.map { GeometryMapper.viewPoint(fromNormalized: $0, imageFit: fit) }
        var mapped: [Joint: CGPoint] = [:]
        for joint in Joint.allCases {
            if let p = joints[joint.rawValue] {
                mapped[joint] = GeometryMapper.viewPoint(fromNormalized: p, imageFit: fit)
            }
        }
        return Paths(
            contour: smoothClosedPath(points: contourPoints),
            skeleton: skeletonPath(joints: mapped),
            jointDots: jointDotsPath(joints: mapped, radius: fit.height * 0.008)
        )
    }

    // MARK: 基础构件

    /// 闭合 Catmull-Rom 平滑:存简化点串、渲染时平滑(docs/03 §3)
    static func smoothClosedPath(points: [CGPoint]) -> CGPath? {
        guard points.count >= 3 else { return nil }
        let path = CGMutablePath()
        let n = points.count
        path.move(to: points[0])
        for i in 0..<n {
            let p0 = points[(i - 1 + n) % n]
            let p1 = points[i]
            let p2 = points[(i + 1) % n]
            let p3 = points[(i + 2) % n]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        path.closeSubpath()
        return path
    }

    static func skeletonPath(joints: [Joint: CGPoint]) -> CGPath? {
        let path = CGMutablePath()
        var drewAny = false
        for (a, b) in Skeleton.edges {
            guard let pa = joints[a], let pb = joints[b] else { continue }
            path.move(to: pa)
            path.addLine(to: pb)
            drewAny = true
        }
        return drewAny ? path : nil
    }

    static func jointDotsPath(joints: [Joint: CGPoint], radius: CGFloat) -> CGPath? {
        guard !joints.isEmpty, radius > 0 else { return nil }
        let path = CGMutablePath()
        for point in joints.values {
            path.addEllipse(in: CGRect(
                x: point.x - radius, y: point.y - radius,
                width: radius * 2, height: radius * 2
            ))
        }
        return path
    }
}
