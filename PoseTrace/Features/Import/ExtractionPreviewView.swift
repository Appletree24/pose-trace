import SwiftUI

/// 提取预览:原图上叠画骨架 + 轮廓,多人时点选候选(docs/03 §6)
struct ExtractionPreviewView: View {
    @Bindable var model: ImportViewModel

    var body: some View {
        VStack(spacing: 12) {
            previewCanvas
            if model.candidates.count > 1 {
                candidatePicker
            }
            warnings
            TextField("模板名称", text: $model.templateName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
        }
        .padding(.vertical)
    }

    private var previewCanvas: some View {
        ZStack {
            if let cgImage = model.photo?.image {
                Image(decorative: cgImage, scale: 1)
                    .resizable()
                    .scaledToFit()
            }
            Canvas { context, size in
                guard let photo = model.photo, let candidate = model.selectedCandidate else { return }
                let paths = OverlayRenderer.previewPaths(
                    joints: candidate.joints,
                    contour: model.contour,
                    aspect: photo.aspect,
                    viewSize: size
                )
                OverlayDrawing.draw(paths, in: &context, style: .both, opacity: 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var candidatePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.candidates.indices, id: \.self) { index in
                    Button("人物 \(index + 1)") {
                        model.selectCandidate(index)
                    }
                    .buttonStyle(.bordered)
                    .tint(index == model.selectedCandidateIndex ? Color.accentColor : Color.secondary)
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder private var warnings: some View {
        if model.contourFailed {
            warningText(ExtractError.noContour.errorDescription ?? "")
        }
        if let candidate = model.selectedCandidate, candidate.isLowQuality {
            warningText(ExtractError.lowQuality(jointCount: candidate.joints.count).errorDescription ?? "")
        }
    }

    private func warningText(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.orange)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
    }
}
