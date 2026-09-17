import Foundation
import Observation

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

    func stop() {
        controller.stop()
    }

    func capture() {
        guard !isCapturing else { return }
        isCapturing = true
        controller.capturePhoto { [weak self] result in
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
