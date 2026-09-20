import Foundation
import Observation
import CoreGraphics
import PhotosUI

/// 导入流程状态机:选图 → 分析 → 预览确认(docs/01 §3)
@MainActor @Observable
final class ImportViewModel {

    enum Phase: Equatable {
        case pickPhoto
        case analyzing
        case preview
    }

    var phase: Phase = .pickPhoto
    /// PhotosPickerItem 在 @Observable 宏展开里解析不到;改用 String id 做观察键
    var pickerItemID: String?
    var photo: AnalyzedPhoto?
    var selectedCandidateIndex = 0
    var contour: [NormalizedPoint] = []
    var contourFailed = false
    var templateName = ""
    /// 保留参考原图 → 相机页可用"幽灵模式"整体半透明叠加(docs/01 P1)
    var keepOriginal = true
    var errorMessage: String?

    private let service = ExtractionService()

    var candidates: [PoseCandidate] { photo?.candidates ?? [] }

    var selectedCandidate: PoseCandidate? {
        guard candidates.indices.contains(selectedCandidateIndex) else { return nil }
        return candidates[selectedCandidateIndex]
    }

    /// 由视图 .task(id: pickerItemID) 触发;item 由视图持有,VM 只存 id 做 task 触发键
    func analyze(item: PhotosUI.PhotosPickerItem) async {
        phase = .analyzing
        errorMessage = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw ExtractError.imageDecodeFailed
            }
            let service = self.service
            let result = try await Task.detached(priority: .userInitiated) {
                try service.analyze(imageData: data)
            }.value
            photo = result
            selectedCandidateIndex = 0
            templateName = Self.defaultName()
            phase = .preview
            await refreshContour()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            pickerItemID = nil
            phase = .pickPhoto
        }
    }

    func selectCandidate(_ index: Int) {
        guard index != selectedCandidateIndex, candidates.indices.contains(index) else { return }
        selectedCandidateIndex = index
        Task { await refreshContour() }
    }

    func refreshContour() async {
        guard let photo, let candidate = selectedCandidate else { return }
        let service = self.service
        let result = await Task.detached(priority: .userInitiated) {
            service.contour(for: candidate, in: photo)
        }.value
        contour = result
        contourFailed = result.isEmpty
    }

    /// 生成模板;缩略图/原图写盘经调用方注入(LibraryStore 持有 TemplateStore)
    func makeTemplate(
        writeThumbnail: (CGImage, String) throws -> Void,
        writeOriginal: (CGImage, String) throws -> Void
    ) -> PoseTemplate? {
        guard let photo, let candidate = selectedCandidate else { return nil }
        let thumbnailFile = "th-\(UUID().uuidString).jpg"
        do {
            try writeThumbnail(photo.image, thumbnailFile)
        } catch {
            errorMessage = "缩略图保存失败:\(error.localizedDescription)"
            return nil
        }
        // 原图写失败不阻塞入库:幽灵模式按钮按 originalFile == nil 禁用(docs/01 P1)
        var originalFile: String?
        if keepOriginal {
            let name = "orig-\(UUID().uuidString).jpg"
            if (try? writeOriginal(photo.image, name)) != nil {
                originalFile = name
            }
        }
        let trimmed = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
        return service.makeTemplate(
            name: trimmed.isEmpty ? Self.defaultName() : trimmed,
            candidate: candidate,
            contour: contour,
            photo: photo,
            thumbnailFile: thumbnailFile,
            originalFile: originalFile
        )
    }

    private static func defaultName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 HH:mm"
        return "姿势 " + formatter.string(from: Date())
    }
}
