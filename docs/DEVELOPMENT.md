# SnapStraight 开发指南

## 开发原则

### 1. 极简主义
- **单一功能**：仅聚焦图片矫正，不添加任何非核心功能
- **最小依赖**：尽量使用系统原生框架，减少第三方库
- **轻量化**：严格控制 APK/IPA 大小 ≤ 2MB

### 2. 用户体验优先
- **零门槛**：操作步骤 ≤ 2步
- **快速响应**：图片处理时间 < 1秒
- **清晰反馈**：每个操作都有明确的视觉或触觉反馈

### 3. 隐私安全
- **本地处理**：所有图片处理在本地完成
- **最小权限**：仅申请必要的相机和存储权限
- **无追踪**：不收集任何用户数据

---

## 代码规范

### Kotlin (Android)

```kotlin
// 类名：大驼峰命名
class ImageProcessor {
    
    // 常量：全大写，下划线分隔
    companion object {
        private const val MAX_IMAGE_SIZE = 2048
    }
    
    // 变量：小驼峰命名
    private var processingQueue: Queue<Bitmap>? = null
    
    // 函数：小驼峰命名，动词开头
    fun processImage(bitmap: Bitmap): Bitmap {
        // 实现
    }
    
    // 私有函数：使用 private
    private fun detectEdges(mat: Mat): List<Point>? {
        // 实现
    }
}
```

### Swift (iOS)

```swift
// 类名：大驼峰命名
class ImageProcessor {
    
    // 常量：小驼峰命名
    private let maxImageSize = 2048
    
    // 变量：小驼峰命名
    private var processingQueue: [UIImage]?
    
    // 函数：小驼峰命名，动词开头
    func processImage(_ image: UIImage) -> UIImage {
        // 实现
    }
    
    // 私有函数：使用 private
    private func detectEdges(in image: CIImage) -> [CGPoint]? {
        // 实现
    }
}
```

---

## 图像处理流程

### 1. 边缘检测

**Android (OpenCV)**
```kotlin
private fun detectEdges(src: Mat): List<Point>? {
    // 1. 转灰度
    val gray = Mat()
    Imgproc.cvtColor(src, gray, Imgproc.COLOR_BGR2GRAY)
    
    // 2. 高斯模糊
    val blurred = Mat()
    Imgproc.GaussianBlur(gray, blurred, Size(5.0, 5.0), 0.0)
    
    // 3. Canny边缘检测
    val edges = Mat()
    Imgproc.Canny(blurred, edges, 75.0, 200.0)
    
    // 4. 查找轮廓
    val contours = ArrayList<MatOfPoint>()
    Imgproc.findContours(edges, contours, ...)
    
    // 5. 筛选最大矩形轮廓
    // ...
}
```

**iOS (Vision)**
```swift
private static func detectRectangle(in image: CIImage) -> VNRectangleObservation? {
    let request = VNDetectRectanglesRequest()
    request.minimumAspectRatio = 0.3
    request.maximumAspectRatio = 3.0
    request.minimumSize = 0.3
    
    let handler = VNImageRequestHandler(ciImage: image, options: [:])
    try? handler.perform([request])
    
    return request.results?.first
}
```

### 2. 透视矫正

**原理**：通过四个角点计算透视变换矩阵，将倾斜的图片拉直。

**关键步骤**：
1. 排序四个角点（左上、右上、右下、左下）
2. 计算目标图片的宽度和高度
3. 构建透视变换矩阵
4. 应用变换

### 3. 自动提亮

**Android (CLAHE)**
```kotlin
private fun autoEnhance(src: Mat): Mat {
    val lab = Mat()
    Imgproc.cvtColor(src, lab, Imgproc.COLOR_BGR2Lab)
    
    val channels = ArrayList<Mat>()
    Core.split(lab, channels)
    
    // CLAHE 增强
    val clahe = Imgproc.createCLAHE(2.0, Size(8.0, 8.0))
    clahe.apply(channels[0], channels[0])
    
    Core.merge(channels, lab)
    
    val enhanced = Mat()
    Imgproc.cvtColor(lab, enhanced, Imgproc.COLOR_Lab2BGR)
    
    return enhanced
}
```

**iOS (Auto Adjust)**
```swift
private static func autoEnhance(_ image: CIImage) -> CIImage {
    let filters = image.autoAdjustmentFilters()
    var output = image
    
    for filter in filters {
        filter.setValue(output, forKey: kCIInputImageKey)
        if let result = filter.outputImage {
            output = result
        }
    }
    
    return output
}
```

---

## 性能优化

### 1. 图片缩放
处理前先将大图缩小，提高处理速度：
```kotlin
val scale = 800.0 / maxOf(src.width(), src.height())
if (scale < 1.0) {
    Imgproc.resize(src, processed, Size(), scale, scale, Imgproc.INTER_AREA)
}
```

### 2. 异步处理
图像处理在后台线程进行，避免阻塞UI：

**Android**
```kotlin
Thread {
    val processed = processImageInternal(bitmap)
    Handler(mainLooper).post {
        onComplete(processed)
    }
}.start()
```

**iOS**
```swift
DispatchQueue.global(qos: .userInitiated).async {
    let processed = processImageInternal(image)
    DispatchQueue.main.async {
        completion(processed)
    }
}
```

### 3. 内存管理
及时释放OpenCV Mat对象：
```kotlin
src.release()
gray.release()
edges.release()
```

---

## 调试技巧

### 1. 边缘检测可视化
```kotlin
// 将边缘检测结果保存为图片查看
val edgesBitmap = Bitmap.createBitmap(edges.width(), edges.height(), Bitmap.Config.ARGB_8888)
Utils.matToBitmap(edges, edgesBitmap)
// 保存或显示 edgesBitmap
```

### 2. 性能测试
```kotlin
val startTime = System.currentTimeMillis()
val processed = processImage(bitmap)
val duration = System.currentTimeMillis() - startTime
Log.d("Performance", "Processing took ${duration}ms")
```

### 3. 日志输出
```kotlin
// Android
Log.d(TAG, "Image size: ${bitmap.width} x ${bitmap.height}")

// iOS
print("Image size: \(image.size.width) x \(image.size.height)")
```

---

## 常见问题

### 1. 边缘检测失败
**原因**：背景过于复杂、光线不足、物体边缘不清晰

**解决**：
- 调整 Canny 阈值参数
- 增加预处理步骤（如形态学操作）
- 降低最小面积要求

### 2. 透视变换后图片变形
**原因**：角点顺序错误

**解决**：
- 确保角点按照固定顺序排列
- 使用几何关系验证角点位置

### 3. 处理速度慢
**原因**：图片尺寸过大

**解决**：
- 处理前先缩小图片
- 使用更快的插值算法
- 优化算法流程

---

## 测试清单

### 功能测试
- [ ] 拍照功能正常
- [ ] 选图功能正常
- [ ] 边缘检测准确（>95%）
- [ ] 透视矫正效果良好
- [ ] 自动提亮效果自然
- [ ] 保存功能正常
- [ ] 多语言切换正常

### 性能测试
- [ ] 处理速度 < 1秒
- [ ] 内存占用 ≤ 50MB
- [ ] APK/IPA 大小 ≤ 2MB
- [ ] 连续操作100次无崩溃

### 兼容性测试
- [ ] Android 7.0+
- [ ] iOS 12.0+
- [ ] 不同屏幕尺寸
- [ ] 不同分辨率相机

---

## 发布检查清单

### Android
- [ ] 启用混淆（ProGuard）
- [ ] 资源压缩（shrinkResources）
- [ ] 签名配置
- [ ] 版本号更新
- [ ] 权限说明完整
- [ ] 多语言文件齐全

### iOS
- [ ] 证书和描述文件
- [ ] Bundle ID 配置
- [ ] 版本号更新
- [ ] 权限描述完整
- [ ] 多语言文件齐全
- [ ] App Store 截图和描述

---

## 持续改进

### 短期计划
1. 优化边缘检测算法
2. 适配更多设备
3. 性能基准测试

### 长期计划
1. 支持更多文档类型
2. AI 增强识别
3. 批量处理功能（可选）

---

## 参考资源

- [OpenCV Documentation](https://docs.opencv.org/)
- [Vision Framework](https://developer.apple.com/documentation/vision)
- [CameraX](https://developer.android.com/training/camerax)
- [Core Image Filters](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Reference/CoreImageFilterReference/)
