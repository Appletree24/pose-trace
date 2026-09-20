import SwiftUI
import PhotosUI

/// 导入流程容器:选图 → 分析进度 → 预览确认 → 保存入库(docs/01 P0-1/2/3)
struct ImportFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LibraryStore.self) private var library
    @State private var model = ImportViewModel()
    @State private var pickerItem: PhotosUI.PhotosPickerItem?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("导入参考照")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismiss() }
                    }
                    if model.phase == .preview {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("保存") { save() }
                        }
                    }
                }
        }
        // 视图持有 PhotosPickerItem(宏展开不 import PhotosUI);itemIdentifier 同步到 VM 做 task 键
        .task(id: model.pickerItemID) {
            guard let pickerItem else { return }
            await model.analyze(item: pickerItem)
        }
        .onChange(of: pickerItem?.itemIdentifier) { _, newID in
            model.pickerItemID = newID
        }
        .interactiveDismissDisabled(model.phase == .analyzing)
    }

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .pickPhoto:
            pickView
        case .analyzing:
            ProgressView("正在提取姿势…")
                .controlSize(.large)
        case .preview:
            ExtractionPreviewView(model: model)
        }
    }

    private var pickView: some View {
        @Bindable var model = model
        return VStack(spacing: 16) {
            Image(systemName: "figure.arms.open")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("选一张带人物的照片\n提取骨架与轮廓作为拍摄参考")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("从相册选择", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.borderedProminent)
            if let message = model.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }

    private func save() {
        let template = model.makeTemplate(
            writeThumbnail: { try library.writeThumbnail($0, named: $1) },
            writeOriginal: { try library.writeOriginal($0, named: $1) }
        )
        guard let template else { return }
        library.add(template)
        dismiss()
    }
}
