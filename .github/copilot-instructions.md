# SnapStraight Copilot Instructions

- 本仓库是完全离线的双端原生项目（Android Kotlin + iOS Swift），只做「拍/选图 → 自动矫正 → 保存」的单一流程，严禁增加联网、账号、广告或体积膨胀功能。
- 体积/性能红线：APK/IPA ≤ 2MB、单张处理 < 1s、运行内存 ≤ 50MB；新增资源/依赖需说明对体积与性能的影响。
- Android 架构：`MainActivity` 两按钮入口（权限通过 `ActivityResultContracts`），去 `CameraActivity` 走 CameraX 预览 + ImageAnalysis 边缘检测，或相册选图后直接进入 `ResultActivity`。`ResultActivity` 用 `QuadOverlayView` 编辑四边形，`ImageProcessor` (OpenCV 4.8) 完成检测、透视矫正、CLAHE 提亮，`ImageSaver` 存相册。
- Android 数据传递：原图与初始四边形通过 `ResultActivity.setOriginalBitmap/setInitialQuad` 静态字段传递，仅适用于同进程流程，勿跨进程或异步持久化；四边形为 0..1 归一化坐标，顺序固定 TL/TR/BR/BL。
- Android 权限：只申请 `CAMERA` 与 Android 13+ 的 `READ_MEDIA_IMAGES`（老版本无需存储写权限即可保存至相册）；保持无网络权限。自动连拍依赖稳定度计数（`CameraActivity` 的 `stabilityThreshold`），调整时确保防抖逻辑与 UI 反馈一致。
- iOS 架构：UIKit 控制器 (`MainViewController/CameraViewController/ResultViewController`) 搭配 `ImageProcessor.swift`。图像流程：先 `fixOrientation`，多组 Vision `VNDetectRectanglesRequest` 配置递进检测，再用 `CIPerspectiveCorrection` 裁正并 `autoEnhance`；支持用户指定的 `NormalizedQuad`（0..1 归一化，TL→TR→BR→BL）。所有处理在后台队列完成，结果回到主线程更新 UI。
- UI/体验约束：界面元素极简（主页仅两大按钮；取景全屏；结果页仅保存+返回），保持震动/提示文案一致，不新增多级菜单或额外操作步骤。
- 多语言：Android `res/values*`，iOS `*.lproj`（已含 zh-Hans/zh-Hant/en/ja/ko/es/fr/de）；新增文案需同步两端并避免文本长度溢出。
- 构建与测试：
  - Android：`cd android && ./gradlew build`，安装 `./gradlew installDebug`，单元测试 `./gradlew test`，发布包 `./gradlew assembleRelease`（已启用混淆和 shrinkResources）。
  - iOS：`cd ios && open SnapStraight.xcodeproj` 运行；命令行测试 `xcodebuild test -scheme SnapStraight -destination 'platform=iOS Simulator,name=iPhone 15'`；Archive 走标准 Product → Archive。
- 关键文件示例：Android `ImageProcessor.kt`（OpenCV 预处理/透视/CLAHE）、`QuadOverlayView.kt`（手势调整四边形）；iOS `ImageProcessor.swift`（多策略矩形检测+透视矫正+提亮）。改动这些需确保角点顺序与坐标系（OpenCV 左上为原点，Vision 归一化原点左下）正确。
- 调试提示：检测失败优先调节阈值/模糊参数或缩放输入；保持 Mat/CIImage 释放与线程切换（后台处理，主线程更新 UI）；保存失败多为权限或路径问题，避免在主线程做重处理。
- 安全与隐私：全流程本地处理、无日志上传；勿引入跟踪 SDK。权限文案在 Android `strings.xml` 与 iOS `Info.plist` 已定义，新增权限需更新说明。
- 依赖基线：Android 使用 CameraX 1.3.1 + Material 1.11 + OpenCV 4.8.0；iOS 仅系统框架（AVFoundation, Vision, CoreImage, Photos）。保持最小依赖集，禁止引入重型库。
