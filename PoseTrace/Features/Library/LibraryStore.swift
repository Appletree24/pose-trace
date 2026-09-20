import Foundation
import Observation
import CoreGraphics

/// 模板库状态:内存列表 + TemplateStore 落盘(docs/02 §2)
@MainActor @Observable
final class LibraryStore {
    private(set) var templates: [PoseTemplate] = []
    var lastError: String?

    private let store: TemplateStore?

    init() {
        do {
            let store = try TemplateStore()
            self.store = store
            templates = store.load()
        } catch {
            store = nil
            lastError = "存储初始化失败:\(error.localizedDescription)"
        }
    }

    func add(_ template: PoseTemplate) {
        templates.insert(template, at: 0)
        persist()
    }

    /// 重命名;空名忽略
    func rename(_ template: PoseTemplate, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = templates.firstIndex(where: { $0.id == template.id }) else { return }
        templates[index].name = trimmed
        persist()
    }

    /// 收藏置顶:重新排序保持 收藏在前(各自按入库倒序)
    func toggleFavorite(_ template: PoseTemplate) {
        guard let index = templates.firstIndex(where: { $0.id == template.id }) else { return }
        templates[index].isFavorite.toggle()
        let favorites = templates.filter(\.isFavorite)
        let rest = templates.filter { !$0.isFavorite }
        templates = favorites + rest
        persist()
    }

    func delete(_ template: PoseTemplate) {
        templates.removeAll { $0.id == template.id }
        store?.deleteThumbnail(named: template.thumbnailFile)
        if let original = template.originalFile {
            store?.deleteOriginal(named: original)
        }
        persist()
    }

    func thumbnailURL(for template: PoseTemplate) -> URL? {
        store?.thumbnailURL(named: template.thumbnailFile)
    }

    func writeThumbnail(_ image: CGImage, named name: String) throws {
        guard let store else { throw CocoaError(.fileNoSuchFile) }
        try store.writeThumbnail(image, named: name)
    }

    func writeOriginal(_ image: CGImage, named name: String) throws {
        guard let store else { throw CocoaError(.fileNoSuchFile) }
        try store.writeOriginal(image, named: name)
    }

    /// 相机页幽灵模式读参考原图;nil = 未保留或文件缺失
    func originalImage(for template: PoseTemplate) -> CGImage? {
        guard let name = template.originalFile else { return nil }
        return store?.originalImage(named: name)
    }

    private func persist() {
        guard let store else { return }
        do {
            try store.save(templates)
        } catch {
            lastError = "保存失败:\(error.localizedDescription)"
        }
    }
}
