import Foundation
import Observation
import CoreGraphics

/// 相机页状态:权限、叠加变换(手势基准值)、拍照(docs/03 §5)
@MainActor @Observable
final class CameraViewModel {
    let template: PoseTemplate
    let controller = CameraController()

    /// nil = 询问中
    var permissionGranted: Bool?
    var transform = OverlayTransform()
    var toast: String?
    var isCapturing = false

    // P1(docs/01 §4):网格线、水平仪、幽灵模式、闪光灯、前摄镜像保存
    var showGrid = false
    var showLevel = false
    var ghostEnabled = false
    var ghostImage: CGImage?
    var flash: FlashMode = .auto {
        didSet { controller.flashMode = flash }
    }
    var mirrorSelfieSave = true
    /// 与 controller.currentPosition 同步;手势驱动的镜像默认值据此设置(docs/03 §4.4)
    private(set) var isFrontCamera = false

    // 手势基准值:手势开始时记录,变化量在基准上叠加,结束后清空
    var gestureBaseScale: Double?
    var gestureBaseRotation: Double?
    var gestureBaseOffset: (x: Double, y: Double)?

    init(template: PoseTemplate) {
        self.template = template
        // 无轮廓的模板(提取失败降级)直接进骨架模式
        if template.contour.isEmpty {
            transform.style = .skeleton
        }
    }

    func start() async {
        let granted = await CameraController.requestPermission()
        permissionGranted = granted
        if granted {
            controller.configureAndStart()
        }
    }

    /// 注入参考原图(幽灵模式);nil 时幽灵按钮禁用
    func setGhostImage(_ image: CGImage?) {
        ghostImage = image
        if image == nil { ghostEnabled = false }
    }

    func toggleGhost() {
        guard ghostImage != nil else { return }
        ghostEnabled.toggle()
    }

    func switchCamera() {
        controller.switchCamera()
        isFrontCamera.toggle()
        // 前摄默认镜像"照镜子"、后摄关(docs/03 §4.4);用户手动切过不再覆盖
        transform.mirrored = isFrontCamera
    }

    func stop() {
        controller.stop()
    }

    func capture() {
        guard !isCapturing else { return }
        isCapturing = true
        let mirror = isFrontCamera && mirrorSelfieSave
        controller.capturePhoto(mirrorResult: mirror) { [weak self] result in
            guard let self else { return }
            Task { @MainActor in
                switch result {
                case .success(let data):
                    do {
                        try await PhotoSaver.save(data)
                        self.showToast("已保存到相册")
                    } catch {
                        self.showToast(error.localizedDescription)
                    }
                case .failure(let error):
                    self.showToast("拍照失败:\(error.localizedDescription)")
                }
                self.isCapturing = false
            }
        }
    }

    /// 双击重置摆放;保留用户选择的样式与透明度
    func resetTransform() {
        var reset = OverlayTransform()
        reset.style = transform.style
        reset.opacity = transform.opacity
        transform = reset
    }

    func cycleStyle() {
        transform.style = transform.style.next
    }

    func toggleMirror() {
        transform.mirrored.toggle()
    }

    private func showToast(_ text: String) {
        toast = text
        Task {
            try? await Task.sleep(for: .seconds(2))
            if self.toast == text { self.toast = nil }
        }
    }
}
