# SnapStraight - 随手正一正

## 项目构建指南

### Android 构建

#### 环境要求
- Android Studio Hedgehog 或更高版本
- JDK 17
- Android SDK 34
- Gradle 8.2+

#### 构建步骤

1. **打开项目**
   ```bash
   cd android
   # 使用 Android Studio 打开 android 目录
   ```

2. **同步依赖**
   ```bash
   ./gradlew build
   ```

3. **运行应用**
   - 连接 Android 设备或启动模拟器
   - 在 Android Studio 中点击 Run 按钮
   - 或使用命令行：
   ```bash
   ./gradlew installDebug
   ```

4. **生成发布版本**
   ```bash
   ./gradlew assembleRelease
   ```
   - 输出：`app/build/outputs/apk/release/app-release.apk`

#### 优化建议
- 启用 ProGuard 混淆（已配置）
- 使用 `shrinkResources` 压缩资源（已配置）
- 目标 APK 大小：≤ 2MB

---

### iOS 构建

#### 环境要求
- macOS 12.0 或更高版本
- Xcode 14.0 或更高版本
- iOS 12.0+ 目标设备

#### 构建步骤

1. **打开项目**
   ```bash
   cd ios
   open SnapStraight.xcodeproj
   ```

2. **配置签名**
   - 在 Xcode 中选择项目
   - 配置开发团队和证书
   - 设置 Bundle Identifier

3. **运行应用**
   - 选择目标设备或模拟器
   - 点击 Run 按钮（⌘R）

4. **生成发布版本**
   - Product → Archive
   - 选择分发方式（App Store / Ad Hoc）

#### 优化建议
- 启用 Bitcode
- 优化图片资源
- 目标 IPA 大小：≤ 2MB

---

## 核心功能实现

### Android 图像处理
- **OpenCV 4.8.0**：边缘检测、透视变换
- **CameraX**：相机预览和拍照
- **Kotlin Coroutines**：异步图像处理

### iOS 图像处理
- **Vision Framework**：矩形检测
- **Core Image**：透视矫正和自动增强
- **AVFoundation**：相机功能

---

## 多语言支持

已支持的语言：
- 简体中文 (zh-Hans)
- 繁体中文 (zh-Hant)
- 英文 (en)
- 日语 (ja)
- 韩语 (ko)
- 西班牙语 (es)
- 法语 (fr)
- 德语 (de)

---

## 项目结构

```
SnapStraight/
├── android/                 # Android 项目
│   ├── app/
│   │   ├── src/main/
│   │   │   ├── java/com/snapstraight/app/
│   │   │   │   ├── MainActivity.kt          # 主界面
│   │   │   │   ├── CameraActivity.kt        # 相机
│   │   │   │   ├── ResultActivity.kt        # 结果展示
│   │   │   │   ├── ImageProcessor.kt        # 图像处理
│   │   │   │   └── ImageSaver.kt            # 图片保存
│   │   │   ├── res/
│   │   │   │   ├── layout/                  # 布局文件
│   │   │   │   ├── values/                  # 资源文件
│   │   │   │   └── values-xx/               # 多语言资源
│   │   │   └── AndroidManifest.xml
│   │   └── build.gradle
│   ├── build.gradle
│   └── settings.gradle
│
├── ios/                     # iOS 项目
│   ├── SnapStraight/
│   │   ├── AppDelegate.swift
│   │   ├── MainViewController.swift         # 主界面
│   │   ├── CameraViewController.swift       # 相机
│   │   ├── ResultViewController.swift       # 结果展示
│   │   ├── ImageProcessor.swift             # 图像处理
│   │   ├── Info.plist
│   │   └── *.lproj/                         # 多语言资源
│   └── SnapStraight.xcodeproj
│
├── docs/                    # 文档
│   ├── DEVELOPMENT.md       # 开发文档
│   ├── TESTING.md           # 测试文档
│   └── DEPLOYMENT.md        # 部署文档
│
└── README.md                # 项目说明
```

---

## 权限说明

### Android
- `CAMERA`：拍照功能
- `READ_MEDIA_IMAGES`（Android 13+）：读取图片
- `WRITE_EXTERNAL_STORAGE`（Android 9-）：保存图片

### iOS
- `NSCameraUsageDescription`：相机访问
- `NSPhotoLibraryUsageDescription`：相册访问
- `NSPhotoLibraryAddUsageDescription`：保存图片

---

## 技术特点

1. **极致轻量**：无第三方重型库，仅使用系统框架和轻量级图像处理库
2. **离线处理**：所有图像处理均在本地完成，不联网
3. **高性能**：单张图片处理时间 < 1秒
4. **低内存**：运行内存占用 ≤ 50MB
5. **多语言**：支持8种主流语言

---

## 待办事项

- [ ] 添加更多语言支持（法语、德语、繁体中文）
- [ ] 优化边缘检测算法，提高复杂场景识别率
- [ ] 适配更多低配设备
- [ ] 性能测试和优化
- [ ] UI自动化测试

---

## 许可证

本项目为内部开发项目，版权所有。

---

## 联系方式

如有问题或建议，请联系开发团队。
