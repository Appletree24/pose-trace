import SwiftUI

/// 叠加层描边样式:白主线 + 黑衬边保证明暗背景可见,骨架用青色系(docs/03 §5)。
/// 几何来自 OverlayRenderer(Core 层);本文件只管样式,是 UI 侧唯一的绘制入口。
enum OverlayDrawing {
    static func draw(
        _ paths: OverlayRenderer.Paths,
        in context: inout GraphicsContext,
        style: OverlayStyle,
        opacity: Double
    ) {
        context.opacity = opacity
        if style != .skeleton, let contour = paths.contour {
            let path = Path(contour)
            context.stroke(
                path,
                with: .color(.black.opacity(0.55)),
                style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
            )
            context.stroke(
                path,
                with: .color(.white),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            )
        }
        if style != .contour {
            if let skeleton = paths.skeleton {
                let path = Path(skeleton)
                context.stroke(
                    path,
                    with: .color(.black.opacity(0.4)),
                    style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                )
                context.stroke(
                    path,
                    with: .color(.cyan),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
            }
            if let dots = paths.jointDots {
                context.fill(Path(dots), with: .color(.cyan))
            }
        }
    }
}
