import Foundation
import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

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

    /// 当前镜头朝向(只读;切镜头走 switchCamera)。sessionQueue 上读写,主线程读用于 UI 展示时以 view model 侧镜像状态为准。
    private(set) var currentPosition: AVCaptureDevice.Position = .back
    /// 闪光灯模式,拍照时写入 AVCapturePhotoSettings(docs/01 P1)
    var flashMode: FlashMode = .auto

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
            currentPosition = position
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
    /// - Parameter mirrorResult: 前摄时是否水平镜像输出(对齐预览"照镜子"观感,docs/01 P1)
    func capturePhoto(mirrorResult: Bool = false, completion: @escaping (Result<Data, Error>) -> Void) {
        sessionQueue.async { [self] in
            let settings = AVCapturePhotoSettings()
            settings.flashMode = AVCaptureDevice.FlashMode(flashMode)
            // 应用锁竖屏(Info.plist),固定 90°;若后续放开横屏,改用 AVCaptureDevice.RotationCoordinator
            if let connection = photoOutput.connection(with: .video),
               connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            let captureID = settings.uniqueID
            let processor = PhotoCaptureProcessor(mirrorHorizontally: mirrorResult) { [weak self] result in
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
    /// 前摄"照镜子"保存:对 fileDataRepresentation 做水平镜像重编码(docs/01 P1)
    private let mirrorHorizontally: Bool

    init(mirrorHorizontally: Bool, completion: @escaping (Result<Data, Error>) -> Void) {
        self.mirrorHorizontally = mirrorHorizontally
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
        guard var data = photo.fileDataRepresentation() else {
            completion(.failure(CocoaError(.fileWriteUnknown)))
            return
        }
        if mirrorHorizontally {
            data = Self.mirrorJPEG(data) ?? data   // 镜像失败时退回原图,不丢照片
        }
        completion(.success(data))
    }

    /// 水平镜像 JPEG:解码 → 翻转 → 重编码。仅用系统框架,保持 Core 层无 UIKit。
    private static func mirrorJPEG(_ data: Data) -> Data? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let width = image.width, height = image.height
        guard let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        context.translateBy(x: CGFloat(width), y: 0)
        context.scaleBy(x: -1, y: 1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let flipped = context.makeImage() else { return nil }
        let out = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            out, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, flipped, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return out as Data
    }
}

private extension AVCaptureDevice.FlashMode {
    init(_ mode: FlashMode) {
        switch mode {
        case .auto: self = .auto
        case .on: self = .on
        case .off: self = .off
        }
    }
}
