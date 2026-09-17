import Foundation
import AVFoundation

/// AVCaptureSession 生命周期与拍照(docs/03 §5)。
/// 所有会话操作在专用串行 sessionQueue(Apple 推荐做法,docs/02 §6);
/// MVP 不挂 VideoDataOutput——零逐帧推理是功耗与流畅度优势的来源(docs/02 D4)。
final class CameraController: NSObject {

    enum CameraError: LocalizedError {
        case permissionDenied
        var errorDescription: String? {
            "没有相机权限。请到 设置 > 隐私与安全性 > 相机 打开。"
        }
    }

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.posetrace.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var position: AVCaptureDevice.Position = .back
    /// 拍照代理须强持有到回调完成;key = AVCapturePhotoSettings.uniqueID
    private var inFlightCaptures: [Int64: PhotoCaptureProcessor] = [:]

    static func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    func configureAndStart() {
        sessionQueue.async { [self] in
            if videoInput == nil {
                session.beginConfiguration()
                session.sessionPreset = .photo
                attachInput(position: position)
                if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
                session.commitConfiguration()
            }
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        sessionQueue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func switchCamera() {
        sessionQueue.async { [self] in
            position = (position == .back) ? .front : .back
            session.beginConfiguration()
            attachInput(position: position)
            session.commitConfiguration()
        }
    }

    private func attachInput(position: AVCaptureDevice.Position) {
        if let existing = videoInput {
            session.removeInput(existing)
            videoInput = nil
        }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return }
        session.addInput(input)
        videoInput = input
    }

    /// 拍照;completion 主线程回调
    func capturePhoto(completion: @escaping (Result<Data, Error>) -> Void) {
        sessionQueue.async { [self] in
            let settings = AVCapturePhotoSettings()
            // 应用锁竖屏(Info.plist),固定 90°;若后续放开横屏,改用 AVCaptureDevice.RotationCoordinator
            if let connection = photoOutput.connection(with: .video),
               connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            let captureID = settings.uniqueID
            let processor = PhotoCaptureProcessor { [weak self] result in
                self?.sessionQueue.async { self?.inFlightCaptures[captureID] = nil }
                DispatchQueue.main.async { completion(result) }
            }
            inFlightCaptures[captureID] = processor
            photoOutput.capturePhoto(with: settings, delegate: processor)
        }
    }
}

private final class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<Data, Error>) -> Void

    init(completion: @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            completion(.failure(error))
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            completion(.failure(CocoaError(.fileWriteUnknown)))
            return
        }
        completion(.success(data))
    }
}
