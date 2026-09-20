import SwiftUI
import UIKit

/// 姿势库(App 首页):模板网格、导入入口、进相机(docs/01 P0-4)
struct LibraryView: View {
    @Environment(LibraryStore.self) private var library
    @State private var showImport = false
    @State private var cameraTemplate: PoseTemplate?
    @State private var renameTarget: PoseTemplate?
    @State private var renameText = ""

    private var renameAlertPresented: Binding<Bool> {
        Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )
    }

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 12)]

    var body: some View {
        Group {
            if library.templates.isEmpty {
                emptyState
            } else {
                grid
            }
        }
        .navigationTitle("姿势库")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showImport = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("导入参考照")
            }
        }
        .sheet(isPresented: $showImport) {
            ImportFlowView()
        }
        .fullScreenCover(item: $cameraTemplate) { template in
            CameraScreen(template: template)
        }
        .alert("重命名", isPresented: renameAlertPresented) {
            TextField("名称", text: $renameText)
            Button("取消", role: .cancel) {}
            Button("确定") {
                if let renameTarget { library.rename(renameTarget, to: renameText) }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("还没有姿势模板", systemImage: "figure.arms.open")
        } description: {
            Text("导入一张喜欢的照片,提取人物姿势作为拍摄参考。")
        } actions: {
            Button("导入参考照") { showImport = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(library.templates) { template in
                    Button {
                        cameraTemplate = template
                    } label: {
                        TemplateCell(template: template)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            library.toggleFavorite(template)
                        } label: {
                            Label(
                                template.isFavorite ? "取消收藏" : "收藏",
                                systemImage: template.isFavorite ? "heart.fill" : "heart"
                            )
                        }
                        Button {
                            renameTarget = template
                            renameText = template.name
                        } label: {
                            Label("重命名", systemImage: "pencil")
                        }
                        Divider()
                        Button(role: .destructive) {
                            library.delete(template)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct TemplateCell: View {
    @Environment(LibraryStore.self) private var library
    let template: PoseTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            thumbnail
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .topTrailing) {
                    if template.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(.black.opacity(0.45), in: Circle())
                            .padding(6)
                    }
                }
            Text(template.name)
                .font(.footnote)
                .lineLimit(1)
        }
    }

    @ViewBuilder private var thumbnail: some View {
        if let url = library.thumbnailURL(for: template),
           let image = UIImage(contentsOfFile: url.path) {
            Color.clear.overlay(
                Image(uiImage: image).resizable().scaledToFill()
            )
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(.quaternary)
                .overlay(Image(systemName: "figure.arms.open").foregroundStyle(.secondary))
        }
    }
}
