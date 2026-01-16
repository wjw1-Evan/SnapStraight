# SnapStraight 部署文档

## 版本发布流程

### Android 发布

#### 1. 准备工作

**更新版本信息**
```gradle
// app/build.gradle
android {
    defaultConfig {
        versionCode 2        // 每次发布递增
        versionName "1.1"    // 遵循语义化版本
    }
}
```

**配置签名**
```gradle
android {
    signingConfigs {
        release {
            storeFile file("path/to/keystore.jks")
            storePassword "***"
            keyAlias "snapstraight"
            keyPassword "***"
        }
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
        }
    }
}
```

#### 2. 构建发布版本

```bash
cd android

# 清理旧构建
./gradlew clean

# 构建发布 APK
./gradlew assembleRelease

# 或构建 AAB (Google Play)
./gradlew bundleRelease
```

输出位置：
- APK: `app/build/outputs/apk/release/app-release.apk`
- AAB: `app/build/outputs/bundle/release/app-release.aab`

#### 3. 测试发布包

```bash
# 安装到测试设备
adb install app/build/outputs/apk/release/app-release.apk

# 验证签名
jarsigner -verify -verbose -certs app-release.apk

# 检查 APK 内容
aapt dump badging app-release.apk
```

#### 4. 上传到应用商店

**Google Play**
1. 登录 [Google Play Console](https://play.google.com/console)
2. 选择应用 → 发布 → 正式版
3. 上传 AAB 文件
4. 填写版本说明（多语言）
5. 提交审核

**华为应用市场**
1. 登录 [华为开发者联盟](https://developer.huawei.com/)
2. 应用服务 → AppGallery Connect
3. 上传 APK
4. 完善应用信息和截图
5. 提交审核

**其他应用市场**
- 小米应用商店
- OPPO 软件商店
- vivo 应用商店
- 应用宝

---

### iOS 发布

#### 1. 准备工作

**更新版本信息**
```swift
// Info.plist
<key>CFBundleShortVersionString</key>
<string>1.1</string>
<key>CFBundleVersion</key>
<string>2</string>
```

**配置证书**
1. 打开 Xcode → Preferences → Accounts
2. 添加 Apple ID
3. 下载证书和描述文件

#### 2. Archive 构建

1. 在 Xcode 中选择 "Any iOS Device"
2. Product → Archive
3. 等待构建完成
4. 在 Organizer 中查看 Archive

#### 3. 上传到 App Store Connect

1. 在 Organizer 中选择 Archive
2. 点击 "Distribute App"
3. 选择 "App Store Connect"
4. 配置选项：
   - Upload Symbols: Yes
   - Bitcode: Yes (如果支持)
   - Strip Swift Symbols: Yes
5. 上传

#### 4. 提交审核

1. 登录 [App Store Connect](https://appstoreconnect.apple.com/)
2. 选择应用
3. 添加新版本
4. 填写版本信息：
   - 版本号
   - 更新说明（多语言）
   - 截图（各种设备尺寸）
   - 预览视频（可选）
5. 选择构建版本
6. 提交审核

---

## 应用商店优化 (ASO)

### 应用名称
- 中文：随手正一正 - 证件票据一键矫正
- 英文：Snap Straight - Document Scanner

### 关键词

**中文**
```
证件矫正,图片拉直,文档扫描,票据识别,照片校正,
身份证拍摄,发票扫描,笔记整理,图片裁剪
```

**英文**
```
document scanner,photo straighten,perspective correction,
ID card scanner,receipt scanner,note scanner,image crop
```

### 应用描述

**简短描述（80字符）**
```
证件票据一键矫正，操作简单，离线处理，隐私安全
```

**完整描述**
```
【随手正一正】是一款专注于图片矫正的极简工具，完美解决身份证、
社保卡、发票、笔记等拍摄倾斜的问题。

✨ 核心功能
• 智能识别边缘，自动矫正倾斜
• 一键裁剪背景，保留主体
• 自动提亮，文字更清晰
• 仅需2步操作，零学习成本

🔒 隐私安全
• 本地处理，不联网
• 不上传服务器
• 无广告，无内购

📦 轻量快速
• 安装包小于2MB
• 处理速度快，不到1秒
• 支持多种语言

适用场景：
✓ 老人拍社保卡报销
✓ 宝妈拍疫苗本存档
✓ 上班族拍发票审核
✓ 学生拍笔记复习
```

### 截图要求

**Android (Google Play)**
- 最少 2 张，最多 8 张
- 尺寸：16:9 比例
- 格式：JPG 或 PNG
- 建议：展示主要功能流程

**iOS (App Store)**
- 6.5" (iPhone 14 Pro Max): 1284 x 2778
- 5.5" (iPhone 8 Plus): 1242 x 2208
- 12.9" (iPad Pro): 2048 x 2732
- 最少 3 张，最多 10 张

### 分类选择

**主类别**
- Android: 工具
- iOS: Utilities (工具)

**副类别**
- Productivity (生产力)
- Photo & Video (照片与视频)

---

## 版本更新策略

### 版本号规则

遵循语义化版本（Semantic Versioning）：
```
主版本号.次版本号.修订号

1.0.0 - 初始发布
1.1.0 - 新增功能
1.1.1 - Bug 修复
2.0.0 - 重大更新
```

### 更新频率

- **Bug 修复**：发现严重 Bug 后 1-3 天内发布
- **功能优化**：每月 1 次
- **新功能**：每季度 1 次（如果有）

### 更新说明模板

```
版本 1.1.0

【新增】
• 支持更多语言（法语、德语）
• 优化暗光环境下的识别效果

【优化】
• 提升边缘检测准确率
• 减少处理时间

【修复】
• 修复部分设备崩溃问题
• 修复保存失败的问题
```

---

## 灰度发布

### Android (Google Play)

1. 在 Play Console 中创建封闭测试轨道
2. 添加测试用户邮箱
3. 上传新版本到测试轨道
4. 收集反馈
5. 逐步提高发布比例：10% → 50% → 100%

### iOS (TestFlight)

1. 上传构建到 App Store Connect
2. 添加内部测试员（最多 100 人）
3. 或添加外部测试员（最多 10,000 人）
4. 收集反馈
5. 提交正式审核

---

## 监控与反馈

### 性能监控

**Android**
- 使用 Firebase Crashlytics（可选）
- Play Console 的 Android vitals
- 自定义性能日志

**iOS**
- Xcode Organizer 的崩溃报告
- App Store Connect 的分析
- TestFlight 反馈

### 用户反馈

**收集渠道**
- 应用商店评论
- 官方邮箱
- 社交媒体（微博、Twitter）

**响应时间**
- 紧急问题：24 小时内
- 一般问题：3 个工作日内
- 功能建议：记录并定期评估

---

## 应急预案

### 严重 Bug 处理流程

1. **紧急评估**（1小时内）
   - 确认 Bug 影响范围
   - 评估严重程度

2. **临时措施**（4小时内）
   - 如需紧急下架，联系平台客服
   - 发布公告告知用户

3. **修复发布**（24小时内）
   - 修复 Bug
   - 快速测试
   - 紧急发布修复版本

4. **事后总结**
   - 分析原因
   - 改进测试流程
   - 防止复发

---

## 合规要求

### 隐私政策

必须包含：
- 收集的信息类型（我们：无）
- 信息使用方式（我们：仅本地处理）
- 第三方分享（我们：无）
- 用户权利
- 联系方式

### 权限说明

Android 和 iOS 都需要在应用商店详情中说明：
- 为什么需要相机权限
- 为什么需要存储/相册权限
- 如何保护用户隐私

### 年龄分级

- Android: 所有人
- iOS: 4+

---

## 检查清单

发布前必查：

### 功能
- [ ] 所有功能正常工作
- [ ] 多语言显示正确
- [ ] 权限申请流程正常

### 性能
- [ ] APK/IPA 大小 ≤ 2MB
- [ ] 处理速度 < 1秒
- [ ] 无内存泄漏

### 合规
- [ ] 隐私政策已更新
- [ ] 权限说明完整
- [ ] 应用信息准确

### 商店
- [ ] 截图已更新
- [ ] 描述已翻译
- [ ] 版本号正确

---

## 发布后

### 首日监控
- 崩溃率
- 下载量
- 用户评分
- 评论反馈

### 首周跟进
- 收集用户反馈
- 修复紧急问题
- 准备 Hotfix（如需要）

### 长期维护
- 定期更新
- 适配新系统
- 优化性能
