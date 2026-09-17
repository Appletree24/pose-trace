import Foundation
import CoreGraphics
import CoreImage
import CoreVideo
import Vision
import simd

/// 分割 mask → 简化多边形轮廓(docs/03 §3)
struct ContourBuilder {
    /// 多边形简化容差(归一化坐标系);经验区间 0.003–0.008,M0 用测试集目测定值
    var epsilon: Float = 0.004

    func contour(from mask: CVPixelBuffer) throws -> [NormalizedPoint] {
        // 二值化拉满对比,避免 mask 灰边产生锯齿轮廓
        var ciImage = CIImage(cvPixelBuffer: mask)
        ciImage = ciImage.applyingFilter("CIColorThreshold", parameters: ["inputThreshold": 0.5])

        let request = VNDetectContoursRequest()
        let handler = VNImageRequestHandler(ciImage: ciImage)
        try handler.perform([request])
        guard let observation = request.results?.first else { throw ExtractError.noContour }

        // 取"面积"最大的顶层轮廓 = 人形外轮廓;内轮廓(手臂与躯干间的洞)MVP 忽略
        let outline = observation.topLevelContours.max { areaProxy($0) < areaProxy($1) }
        guard let outline else { throw ExtractError.noContour }

        let simplified = (try? outline.polygonApproximation(epsilon: epsilon)) ?? outline
        let points = simplified.normalizedPoints.map {
            NormalizedPoint(x: Double($0.x), y: Double($0.y))
        }
        guard points.count >= 3 else { throw ExtractError.noContour }
        return points
    }

    /// 以包围盒面积近似轮廓面积(排序用,足够)
    private func areaProxy(_ contour: VNContour) -> CGFloat {
        let box = contour.normalizedPath.boundingBox
        return box.width * box.height
    }
}
