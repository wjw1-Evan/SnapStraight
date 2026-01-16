# 快速开始指南

## Android 快速运行

### 使用 Android Studio

1. **克隆项目**
   ```bash
   git clone <repository-url>
   cd SnapStraight
   ```

2. **打开 Android 项目**
   - 启动 Android Studio
   - 选择 "Open an Existing Project"
   - 选择 `SnapStraight/android` 目录

3. **同步项目**
   - Android Studio 会自动开始同步 Gradle
   - 等待依赖下载完成

4. **运行应用**
   - 连接 Android 设备或启动模拟器
   - 点击工具栏的绿色运行按钮 ▶️
   - 或按快捷键 `Shift + F10`

### 使用命令行

```bash
cd android

# 首次构建
./gradlew build

# 安装到设备
./gradlew installDebug

# 运行
adb shell am start -n com.snapstraight.app/.MainActivity
```

---

## iOS 快速运行

### 使用 Xcode

1. **克隆项目**
   ```bash
   git clone <repository-url>
   cd SnapStraight
   ```

2. **打开 iOS 项目**
   ```bash
   cd ios
   open SnapStraight.xcodeproj
   ```

3. **配置签名**
   - 选择项目 "SnapStraight"
   - 在 "Signing & Capabilities" 标签页
   - 选择你的开发团队

4. **运行应用**
   - 选择目标设备或模拟器
   - 点击运行按钮 ▶️
   - 或按快捷键 `⌘R`

---

## 功能测试

### 测试流程

1. **拍照测试**
   - 点击"拍照"按钮
   - 对准一张卡片或文档
   - 点击圆形拍照按钮
   - 查看自动矫正后的效果
   - 点击"保存"

2. **选图测试**
   - 点击"选图"按钮
   - 从相册选择一张倾斜的照片
   - 查看自动矫正后的效果
   - 点击"保存"

3. **多语言测试**
   - 更改系统语言
   - 重启应用
   - 验证界面文字正确显示

---

## 常见问题

### Android

**问题：Gradle 同步失败**
```
解决：
1. 检查网络连接
2. 更新 Android Studio
3. 清理并重新构建：Build → Clean Project
```

**问题：无法安装到设备**
```
解决：
1. 检查 USB 调试是否开启
2. 运行 adb devices 确认设备已连接
3. 重启 adb server：adb kill-server && adb start-server
```

**问题：OpenCV 库加载失败**
```
解决：
1. 检查 build.gradle 中的 OpenCV 依赖
2. 确保网络正常，重新同步依赖
3. 清理并重新构建项目
```

### iOS

**问题：签名错误**
```
解决：
1. 在 Xcode 中配置开发团队
2. 确保 Bundle ID 唯一
3. 更新证书和描述文件
```

**问题：模拟器运行失败**
```
解决：
1. 重启 Xcode
2. 重置模拟器：Device → Erase All Content and Settings
3. 清理构建：Product → Clean Build Folder (⌘⇧K)
```

**问题：相机无法使用**
```
解决：
1. 使用真实设备测试（模拟器无相机）
2. 检查 Info.plist 中的权限描述
```

---

## 项目依赖

### Android

```gradle
// app/build.gradle
dependencies {
    // 核心库
    implementation 'androidx.core:core-ktx:1.12.0'
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'com.google.android.material:material:1.11.0'
    
    // 相机
    implementation 'androidx.camera:camera-camera2:1.3.1'
    implementation 'androidx.camera:camera-lifecycle:1.3.1'
    implementation 'androidx.camera:camera-view:1.3.1'
    
    // 图像处理
    implementation 'org.opencv:opencv:4.8.0'
}
```

### iOS

```
无需额外依赖，全部使用系统框架：
- UIKit
- AVFoundation
- Vision
- CoreImage
- Photos
```

---

## 下一步

- 阅读 [开发文档](docs/DEVELOPMENT.md)
- 查看 [构建指南](BUILD.md)
- 了解 [部署流程](docs/DEPLOYMENT.md)

---

## 技术支持

遇到问题？
- 查看 [常见问题](#常见问题)
- 阅读完整的 [README](README.md)
- 联系开发团队
