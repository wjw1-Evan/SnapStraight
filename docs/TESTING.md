# SnapStraight 测试文档

## 测试策略

### 测试金字塔
```
        /\
       /  \  E2E测试 (10%)
      /----\
     /      \  集成测试 (20%)
    /--------\
   /          \  单元测试 (70%)
  /--------------\
```

---

## 单元测试

### Android (JUnit + Mockito)

**ImageProcessor 测试**
```kotlin
class ImageProcessorTest {
    
    @Test
    fun testEdgeDetection() {
        val bitmap = createTestBitmap()
        val corners = ImageProcessor.detectEdges(bitmap)
        
        assertNotNull(corners)
        assertEquals(4, corners.size)
    }
    
    @Test
    fun testPerspectiveTransform() {
        val bitmap = createTestBitmap()
        val corners = listOf(/* 测试角点 */)
        val result = ImageProcessor.perspectiveTransform(bitmap, corners)
        
        assertNotNull(result)
        assertTrue(result.width > 0)
        assertTrue(result.height > 0)
    }
    
    @Test
    fun testAutoEnhance() {
        val bitmap = createDarkBitmap()
        val enhanced = ImageProcessor.autoEnhance(bitmap)
        
        val avgBrightnessBefore = calculateAverageBrightness(bitmap)
        val avgBrightnessAfter = calculateAverageBrightness(enhanced)
        
        assertTrue(avgBrightnessAfter > avgBrightnessBefore)
    }
}
```

**运行测试**
```bash
cd android
./gradlew test
```

### iOS (XCTest)

**ImageProcessor 测试**
```swift
class ImageProcessorTests: XCTestCase {
    
    func testRectangleDetection() {
        let image = createTestImage()
        let rectangle = ImageProcessor.detectRectangle(in: CIImage(image: image)!)
        
        XCTAssertNotNil(rectangle)
        XCTAssertEqual(rectangle?.topLeft != nil, true)
    }
    
    func testPerspectiveCorrection() {
        let image = createTestImage()
        let ciImage = CIImage(image: image)!
        let corners = createTestCorners()
        
        let corrected = ImageProcessor.perspectiveCorrect(ciImage, corners: corners)
        
        XCTAssertNotNil(corrected)
    }
    
    func testAutoEnhance() {
        let image = createDarkImage()
        let ciImage = CIImage(image: image)!
        
        let enhanced = ImageProcessor.autoEnhance(ciImage)
        
        XCTAssertNotNil(enhanced)
        // 验证亮度提升
    }
}
```

**运行测试**
```bash
# 在 Xcode 中
Product → Test (⌘U)

# 或命令行
xcodebuild test -scheme SnapStraight -destination 'platform=iOS Simulator,name=iPhone 15'
```

---

## 集成测试

### Android (Espresso)

**UI 流程测试**
```kotlin
@RunWith(AndroidJUnit4::class)
class MainActivityTest {
    
    @get:Rule
    val activityRule = ActivityScenarioRule(MainActivity::class.java)
    
    @Test
    fun testTakePhotoFlow() {
        // 点击拍照按钮
        onView(withId(R.id.btnTakePhoto))
            .perform(click())
        
        // 验证进入相机页面
        onView(withId(R.id.previewView))
            .check(matches(isDisplayed()))
    }
    
    @Test
    fun testSelectPhotoFlow() {
        // 点击选图按钮
        onView(withId(R.id.btnSelectPhoto))
            .perform(click())
        
        // 验证打开相册选择器
        // （需要使用 Intents）
    }
    
    @Test
    fun testSaveImage() {
        // 模拟处理完成后的结果页
        // 点击保存按钮
        onView(withId(R.id.btnSave))
            .perform(click())
        
        // 验证显示成功提示
        onView(withText(R.string.save_success))
            .check(matches(isDisplayed()))
    }
}
```

### iOS (XCUITest)

**UI 流程测试**
```swift
class SnapStraightUITests: XCTestCase {
    
    func testTakePhotoFlow() {
        let app = XCUIApplication()
        app.launch()
        
        // 点击拍照按钮
        app.buttons["拍照"].tap()
        
        // 验证相机界面
        XCTAssert(app.otherElements["previewView"].exists)
    }
    
    func testSelectPhotoFlow() {
        let app = XCUIApplication()
        app.launch()
        
        // 点击选图按钮
        app.buttons["选图"].tap()
        
        // 验证相册选择器
        // （需要权限）
    }
    
    func testMultiLanguage() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(ja)"]
        app.launch()
        
        // 验证日语界面
        XCTAssert(app.buttons["撮影"].exists)
    }
}
```

---

## 功能测试

### 测试用例清单

#### 1. 拍照功能
| 用例ID | 测试步骤 | 预期结果 | 优先级 |
|--------|---------|---------|--------|
| TC-001 | 点击拍照按钮 | 打开相机界面 | P0 |
| TC-002 | 拒绝相机权限 | 显示权限提示 | P0 |
| TC-003 | 拍摄并处理 | 自动跳转结果页 | P0 |
| TC-004 | 点击返回按钮 | 返回主页 | P1 |

#### 2. 选图功能
| 用例ID | 测试步骤 | 预期结果 | 优先级 |
|--------|---------|---------|--------|
| TC-101 | 点击选图按钮 | 打开相册 | P0 |
| TC-102 | 拒绝相册权限 | 显示权限提示 | P0 |
| TC-103 | 选择图片 | 自动处理并跳转 | P0 |
| TC-104 | 取消选择 | 停留在主页 | P1 |

#### 3. 图像处理
| 用例ID | 测试内容 | 预期结果 | 优先级 |
|--------|---------|---------|--------|
| TC-201 | 矩形证件（身份证） | 准确率 ≥ 99% | P0 |
| TC-202 | 不规则票据 | 准确率 ≥ 98% | P0 |
| TC-203 | 横线笔记 | 准确率 ≥ 98% | P0 |
| TC-204 | 复杂背景 | 准确率 ≥ 95% | P1 |
| TC-205 | 暗光环境 | 自动提亮 | P1 |
| TC-206 | 倾斜 45° | 正确矫正 | P0 |

#### 4. 保存功能
| 用例ID | 测试步骤 | 预期结果 | 优先级 |
|--------|---------|---------|--------|
| TC-301 | 点击保存按钮 | 保存成功 | P0 |
| TC-302 | 拒绝存储权限 | 显示权限提示 | P0 |
| TC-303 | 保存后返回 | 自动返回主页 | P1 |
| TC-304 | 检查相册 | 图片已保存 | P0 |

---

## 性能测试

### 测试指标

#### 1. 处理速度
```
测试方法：
1. 准备10张不同尺寸的测试图片
2. 记录每张图片的处理时间
3. 计算平均值和最大值

通过标准：
- 平均处理时间 < 1秒
- 最大处理时间 < 2秒
```

#### 2. 内存占用
```
测试方法：
1. 启动应用，记录初始内存
2. 连续处理20张图片
3. 记录峰值内存和平稳内存

通过标准：
- 运行时内存 ≤ 50MB
- 无内存泄漏
```

#### 3. 安装包大小
```
测试方法：
1. 构建 Release 版本
2. 检查 APK/IPA 文件大小

通过标准：
- Android APK ≤ 2MB
- iOS IPA ≤ 2MB
```

### 压力测试

**连续操作测试**
```
测试方法：
1. 自动化脚本连续执行100次：
   - 选图
   - 处理
   - 保存
   - 返回
2. 监控性能指标

通过标准：
- 无崩溃
- 无内存泄漏
- 性能稳定
```

---

## 兼容性测试

### Android 测试矩阵

| 品牌 | 型号 | 系统版本 | 屏幕尺寸 | 优先级 |
|------|------|---------|---------|--------|
| 华为 | Mate 40 | Android 10 | 6.5" | P0 |
| 小米 | Mi 11 | Android 11 | 6.81" | P0 |
| OPPO | Find X3 | Android 11 | 6.7" | P1 |
| vivo | X60 | Android 11 | 6.56" | P1 |
| 三星 | S21 | Android 12 | 6.2" | P1 |
| Google | Pixel 6 | Android 13 | 6.4" | P0 |
| 老年机 | 红米9A | Android 10 | 6.53" | P0 |

### iOS 测试矩阵

| 型号 | 系统版本 | 屏幕尺寸 | 优先级 |
|------|---------|---------|--------|
| iPhone 15 Pro | iOS 17 | 6.1" | P0 |
| iPhone 14 | iOS 16 | 6.1" | P0 |
| iPhone 13 | iOS 15 | 6.1" | P1 |
| iPhone 12 | iOS 14 | 6.1" | P1 |
| iPhone SE 3 | iOS 15 | 4.7" | P0 |
| iPhone 8 | iOS 12 | 4.7" | P1 |
| iPad Pro | iPadOS 17 | 12.9" | P2 |

---

## 多语言测试

### 测试语言列表
- ✅ 简体中文 (zh-Hans)
- ✅ 繁体中文 (zh-Hant)
- ✅ 英文 (en)
- ✅ 日语 (ja)
- ✅ 韩语 (ko)
- ✅ 西班牙语 (es)
- ⏳ 法语 (fr)
- ⏳ 德语 (de)

### 测试检查点
- [ ] 所有界面文字正确翻译
- [ ] 无乱码或显示错误
- [ ] 文字长度适配布局
- [ ] 从右到左语言支持（如阿拉伯语）

---

## 用户体验测试

### 测试用户组

1. **中老年用户组**（50-70岁，10人）
   - 测试操作难易度
   - 记录完成时间
   - 收集反馈意见

2. **儿童用户组**（8-12岁，5人）
   - 测试界面理解度
   - 记录操作错误
   - 观察使用习惯

3. **普通用户组**（20-50岁，20人）
   - 测试整体体验
   - 对比竞品
   - 收集改进建议

### 评估指标

```
1. 首次使用成功率：目标 > 90%
2. 平均完成时间：目标 < 30秒
3. 用户满意度：目标 ≥ 4.5/5.0
4. 推荐意愿：目标 > 80%
```

---

## 安全测试

### 隐私检查
- [ ] 无网络请求
- [ ] 无数据上传
- [ ] 无日志记录
- [ ] 权限仅限必要

### 代码安全
- [ ] 无硬编码密钥
- [ ] 无敏感信息泄露
- [ ] 混淆配置正确
- [ ] 签名验证通过

---

## 回归测试

### 测试时机
- 每次代码提交
- 发布前必测
- 重大功能变更

### 测试范围
- 核心功能（必测）
- 历史 Bug（必测）
- 新增功能（必测）
- 其他功能（抽测）

---

## 测试报告模板

```markdown
# 测试报告

## 基本信息
- 版本：v1.0.0
- 测试日期：2024-01-15
- 测试人员：张三
- 测试环境：Android 12, iOS 16

## 测试结果
- 测试用例总数：150
- 通过：148
- 失败：2
- 阻塞：0

## 失败用例
1. TC-203: 横线笔记识别率 97%（目标 98%）
2. TC-302: iOS 存储权限提示显示延迟

## 性能数据
- 平均处理时间：0.8秒 ✅
- 内存占用：42MB ✅
- APK大小：1.8MB ✅

## 建议
1. 优化笔记识别算法
2. 修复 iOS 权限提示延迟问题

## 结论
整体质量良好，建议修复已知问题后发布。
```

---

## 自动化测试

### CI/CD 集成

**Android (GitHub Actions)**
```yaml
name: Android CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Set up JDK
        uses: actions/setup-java@v2
        with:
          java-version: '17'
      - name: Run tests
        run: ./gradlew test
      - name: Build APK
        run: ./gradlew assembleRelease
```

**iOS (GitHub Actions)**
```yaml
name: iOS CI

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run tests
        run: xcodebuild test -scheme SnapStraight
      - name: Build IPA
        run: xcodebuild archive -scheme SnapStraight
```

---

## 测试工具

### Android
- JUnit: 单元测试
- Mockito: Mock框架
- Espresso: UI测试
- Android Profiler: 性能分析

### iOS
- XCTest: 单元测试和UI测试
- Instruments: 性能分析
- TestFlight: Beta测试

### 通用
- Postman: API测试（如有）
- Charles: 网络抓包
- ADB/libimobiledevice: 设备调试
