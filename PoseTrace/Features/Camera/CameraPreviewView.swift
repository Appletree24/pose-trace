import SwiftUI
import AVFoundation

/// AVCaptureVideoPreviewLayer 的 SwiftUI 包装(docs/03 §5)
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        // 连接在会话异步配置完成后才存在,借 SwiftUI 的重绘时机补设方向。
        // 应用锁竖屏,固定 90°;若预览方向仍不对,改用 AVCaptureDevice.RotationCoordinator(见 SETUP.md)
        if let connection = uiView.previewLayer.connection,
           connection.isVideoRotationAngleSupported(90),
           connection.videoRotationAngle != 90 {
            connection.videoRotationAngle = 90
        }
    }
}
