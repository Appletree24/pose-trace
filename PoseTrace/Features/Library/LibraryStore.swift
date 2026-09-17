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

    func delete(_ template: PoseTemplate) {
        templates.removeAll { $0.id == template.id }
        store?.deleteThumbnail(named: template.thumbnailFile)
        persist()
    }

    func thumbnailURL(for template: PoseTemplate) -> URL? {
        store?.thumbnailURL(named: template.thumbnailFile)
    }

    func writeThumbnail(_ image: CGImage, named name: String) throws {
        guard let store else { throw CocoaError(.fileNoSuchFile) }
        try store.writeThumbnail(image, named: name)
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
