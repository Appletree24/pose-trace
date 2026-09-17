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
    var pickerItem: PhotosPickerItem?
    var photo: AnalyzedPhoto?
    var selectedCandidateIndex = 0
    var contour: [NormalizedPoint] = []
    var contourFailed = false
    var templateName = ""
    var errorMessage: String?

    private let service = ExtractionService()

    var candidates: [PoseCandidate] { photo?.candidates ?? [] }

    var selectedCandidate: PoseCandidate? {
        guard candidates.indices.contains(selectedCandidateIndex) else { return nil }
        return candidates[selectedCandidateIndex]
    }

    /// 由视图 onChange(of: pickerItem) 触发
    func analyzePickedItem() async {
        guard let item = pickerItem else { return }
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
            pickerItem = nil
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

    /// 生成模板;缩略图写盘经调用方注入(LibraryStore 持有 TemplateStore)
    func makeTemplate(writeThumbnail: (CGImage, String) throws -> Void) -> PoseTemplate? {
        guard let photo, let candidate = selectedCandidate else { return nil }
        let thumbnailFile = UUID().uuidString + ".jpg"
        do {
            try writeThumbnail(photo.image, thumbnailFile)
        } catch {
            errorMessage = "缩略图保存失败:\(error.localizedDescription)"
            return nil
        }
        let trimmed = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
        return service.makeTemplate(
            name: trimmed.isEmpty ? Self.defaultName() : trimmed,
            candidate: candidate,
            contour: contour,
            photo: photo,
            thumbnailFile: thumbnailFile
        )
    }

    private static func defaultName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 HH:mm"
        return "姿势 " + formatter.string(from: Date())
    }
}
