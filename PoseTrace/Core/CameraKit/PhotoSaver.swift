import Foundation
import Photos

/// 相册"仅添加"级保存(docs/02 §4)
enum PhotoSaver {
    enum SaveError: LocalizedError {
        case permissionDenied
        var errorDescription: String? {
            "没有相册权限,无法保存。请到 设置 > 隐私与安全性 > 照片 允许添加。"
        }
    }

    static func save(_ photoData: Data) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw SaveError.permissionDenied }
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: photoData, options: nil)
        }
    }
}
