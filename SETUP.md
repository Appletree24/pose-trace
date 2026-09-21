# SETUP · 在 Mac 上构建 PoseTrace

> 本仓库代码在无 iOS 环境的机器上编写,**未经编译验证**。按下面步骤生成工程后,首次构建预期需要少量修正,重点核对项见 §4。

## 1. 前置条件

- Mac + Xcode 16 或更新(含 iOS 17+ SDK)
- 真机调试:一台 iOS 17+ 的 iPhone + 免费 Apple ID 即可(签名 7 天有效)
- 相机功能必须真机;模拟器可验证:导入提取、预览、姿势库(先把测试照片拖进模拟器相册)

## 2. 生成工程(二选一)

### 方式 A:XcodeGen(推荐,工程定义已写好)

```sh
brew install xcodegen
cd <本目录>
xcodegen generate
open PoseTrace.xcodeproj
```

然后在 Target > Signing & Capabilities 里选择你的 Team。

### 方式 B:手动创建工程

1. Xcode > New Project > iOS App,Product Name = `PoseTrace`,Interface = SwiftUI,语言 Swift
2. 最低部署版本设为 iOS 17.0;删除模板生成的 `ContentView.swift` 与 `PoseTraceApp.swift`
3. 把 `PoseTrace/` 下的 `App/ Features/ Core/` 文件夹拖入工程(勾选 Create groups + 加入 App target)
4. Target > Info 指向 `PoseTrace/Resources/Info.plist`(或手动补两条权限文案与竖屏锁定)
5. New Target > Unit Testing Bundle,名为 `PoseTraceTests`,拖入 `Tests/PoseTraceTests/` 下三个文件
6. `.gitignore` 中删掉 `PoseTrace.xcodeproj/` 一行(手建工程通常要提交)

## 3. 验证顺序(对应 docs/04 M0)

1. `Cmd+U` 跑单元测试(纯逻辑,应全绿;这是对 GeometryMapper/打分器/存储的回归保障)
2. 模拟器:导入一张全身照 → 预览页应显示骨架 + 轮廓 → 保存 → 姿势库出现缩略图
3. 真机:进相机 → 轮廓叠加 → 双指缩放/旋转、拖动、镜像、透明度、双击重置 → 拍照 → 相册确认
4. 按 docs/04 §2 准备 20 张测试集跑提取质量,记录通过率

## 4. 首次构建重点核对项(按可能性排序)

| # | 位置 | 风险点 | 处理 |
| --- | --- | --- | --- |
| 1 | PersonSegmenter.swift | `VNGeneratePersonInstanceMaskRequest` / `VNInstanceMaskObservation.generateMask(forInstances:)` 的确切签名 | 以 Xcode 自动补全为准微调;`instanceMask` 像素格式假设为 OneComponent8,不符时代码自动回退整体分割(行为已兜底) |
| 2 | ContourBuilder.swift | `CIColorThreshold` 滤镜与 `VNContour.polygonApproximation(epsilon:)` | 若轮廓恒为空:去掉阈值滤镜直接喂 mask,或调 `VNDetectContoursRequest.contrastAdjustment` |
| 3 | CameraScreen.swift | `MagnifyGesture` / `RotateGesture` 为 iOS 17 API | 如需支持 iOS 16 改用 `MagnificationGesture` / `RotationGesture` 并同步调低部署版本(不建议,见 docs/02 D1) |
| 4 | CameraPreviewView.swift | 预览方向依赖"锁竖屏 + 90°补设" | 若方向异常,改用 `AVCaptureDevice.RotationCoordinator`(docs/03 §5 已注明) |
| 5 | 并发警告 | `AnalyzedPhoto`(含 CGImage)跨 `Task.detached` 传递,严格并发模式下会告警 | Swift 5 语言模式默认可编译;如开 strict concurrency,给 `AnalyzedPhoto` 加 `@unchecked Sendable` 包装并注明理由 |
| 6 | project.yml | XcodeGen 字段随版本演进 | 按 `xcodegen generate` 报错提示微调 |
| 7 | ImportFlowView.swift | `PhotosPickerItem` 不遵守 `Equatable` → `onChange` 报错 | 改用 `.task(id: pickerItem?.itemIdentifier)`;id 是 `String?` 天然 `Equatable` |
| 8 | ImportViewModel.swift | `PhotosPickerItem` 是 `PhotosUI` **顶层**类型:不能写 `PhotosUI.PhotosPickerItem`;同时 `@Observable` 宏展开文件不继承 `import PhotosUI`,裸名也解析不到 | VM 完全不持该类型:属性只存 `pickerItemID: String?`,方法签名收 `Data`;`loadTransferable` 在 View 层做 |

## 5. 目录速览

```
project.yml                  XcodeGen 工程定义
PoseTrace/
  App/                       入口(PoseTraceApp)
  Features/
    Library/                 姿势库首页 + 状态(LibraryView/LibraryStore)
    Import/                  导入流程(ImportFlowView/ImportViewModel/ExtractionPreviewView)
    Camera/                  相机页(CameraScreen/CameraViewModel/CameraPreviewView/OverlayDrawing)
  Core/                      无 UI 依赖,可单测(docs/02 §2)
    PoseKit/                 提取/分割/轮廓/几何/打分(Joint/PoseTemplate/…/PoseComparator)
    CameraKit/               会话与拍照(CameraController/PhotoSaver)
    Persistence/             模板存储(TemplateStore/ImageEncoding)
    Support/                 图像解码(ImageLoader)
  Resources/Info.plist       权限文案、竖屏锁定、显示名"摹拍"
Tests/PoseTraceTests/        GeometryMapper/TemplateStore/PoseComparator 单测
docs/                        实现方案(01–04)
```

## 6. 与 docs/ 方案的已知差异

- `OverlayTransform` 字段名比 docs/02 的示意更细:`rotationRadians` / `offsetX` / `offsetY`(避开 CGSize 的编码歧义)
- 缩略图用 JPEG(ImageIO 通用编码)而非 HEIC,Core 层因此无需 UIKit
- TemplateStore 的磁盘 IO 在主线程执行(模板量级小);出现卡顿再移后台
