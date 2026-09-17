import SwiftUI
import UIKit

/// 相机页:预览 + 轮廓叠加 + 手势对齐 + 拍照(docs/01 P0-5/6)
struct CameraScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var model: CameraViewModel

    init(template: PoseTemplate) {
        _model = State(initialValue: CameraViewModel(template: template))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch model.permissionGranted {
            case .some(true):
                cameraContent
            case .some(false):
                deniedView
            case .none:
                ProgressView().tint(.white)
            }
        }
        .task { await model.start() }
        .onDisappear { model.stop() }
        .statusBarHidden()
    }

    // MARK: 相机内容

    private var cameraContent: some View {
        ZStack {
            CameraPreviewView(session: model.controller.session)
                .ignoresSafeArea()
            overlayCanvas
            controls
            if let toast = model.toast {
                toastView(toast)
            }
        }
    }

    private var overlayCanvas: some View {
        Canvas { context, size in
            let paths = OverlayRenderer.cameraPaths(
                template: model.template,
                user: model.transform,
                viewSize: size
            )
            OverlayDrawing.draw(paths, in: &context, style: model.transform.style, opacity: model.transform.opacity)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .gesture(dragGesture.simultaneously(with: magnifyGesture).simultaneously(with: rotateGesture))
        .onTapGesture(count: 2) { model.resetTransform() }
    }

    // MARK: 手势(基准值 + 变化量,docs/03 §5)

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if model.gestureBaseOffset == nil {
                    model.gestureBaseOffset = (model.transform.offsetX, model.transform.offsetY)
                }
                guard let base = model.gestureBaseOffset else { return }
                model.transform.offsetX = base.x + Double(value.translation.width)
                model.transform.offsetY = base.y + Double(value.translation.height)
            }
            .onEnded { _ in model.gestureBaseOffset = nil }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if model.gestureBaseScale == nil {
                    model.gestureBaseScale = model.transform.scale
                }
                guard let base = model.gestureBaseScale else { return }
                model.transform.scale = min(4, max(0.3, base * Double(value.magnification)))
            }
            .onEnded { _ in model.gestureBaseScale = nil }
    }

    private var rotateGesture: some Gesture {
        RotateGesture()
            .onChanged { value in
                if model.gestureBaseRotation == nil {
                    model.gestureBaseRotation = model.transform.rotationRadians
                }
                guard let base = model.gestureBaseRotation else { return }
                model.transform.rotationRadians = base + value.rotation.radians
            }
            .onEnded { _ in model.gestureBaseRotation = nil }
    }

    // MARK: 控制条

    private var controls: some View {
        VStack {
            HStack {
                Button { dismiss() } label: { Image(systemName: "xmark") }
                Spacer()
                Text(model.template.name).font(.subheadline).lineLimit(1)
                Spacer()
                Button { model.controller.switchCamera() } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                }
            }
            .font(.title3)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 14) {
                HStack(spacing: 18) {
                    Button { model.cycleStyle() } label: {
                        Image(systemName: styleIcon)
                    }
                    Button { model.toggleMirror() } label: {
                        Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                            .symbolVariant(model.transform.mirrored ? .fill : .none)
                    }
                    Slider(
                        value: Binding(
                            get: { model.transform.opacity },
                            set: { model.transform.opacity = $0 }
                        ),
                        in: 0.3...0.8
                    )
                    Button { model.resetTransform() } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                }
                .font(.title3)
                .foregroundStyle(.white)
                .tint(.white)

                shutterButton
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
    }

    private var styleIcon: String {
        switch model.transform.style {
        case .contour: return "person.crop.rectangle"
        case .skeleton: return "figure.walk"
        case .both: return "person.and.background.dotted"
        }
    }

    private var shutterButton: some View {
        Button { model.capture() } label: {
            ZStack {
                Circle().strokeBorder(.white, lineWidth: 4).frame(width: 74, height: 74)
                Circle().fill(.white).frame(width: 60, height: 60)
            }
        }
        .disabled(model.isCapturing)
        .opacity(model.isCapturing ? 0.5 : 1)
        .accessibilityLabel("拍照")
    }

    // MARK: 权限被拒 / 提示

    private var deniedView: some View {
        VStack(spacing: 14) {
            Text(CameraController.CameraError.permissionDenied.errorDescription ?? "")
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Button("去设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .buttonStyle(.borderedProminent)
            Button("关闭") { dismiss() }
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(32)
    }

    private func toastView(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.black.opacity(0.7), in: Capsule())
                .foregroundStyle(.white)
                .padding(.bottom, 130)
        }
        .allowsHitTesting(false)
    }
}
