import CoreImage
import UIKit
import Vision

/// 图像处理核心类
/// 实现边缘检测、透视矫正、自动裁剪、亮度优化等功能
class ImageProcessor {

    struct NormalizedQuad {
        let topLeft: CGPoint
        let topRight: CGPoint
        let bottomRight: CGPoint
        let bottomLeft: CGPoint
    }

    /**
     * 处理图片主流程
     */
    static func processImage(
        _ image: UIImage,
        preferredQuad: NormalizedQuad? = nil,
        completion: @escaping (UIImage) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let processed = processImageInternal(image, preferredQuad: preferredQuad)
            DispatchQueue.main.async {
                completion(processed)
            }
        }
    }

    /// 使用用户指定四边形进行拉平与增强
    static func processImageWithQuad(
        _ image: UIImage,
        quad: NormalizedQuad,
        completion: @escaping (UIImage) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let cgImage = image.cgImage else {
                DispatchQueue.main.async { completion(image) }
                return
            }
            let orientation = CGImagePropertyOrientation(image.imageOrientation)
            let ciImage = CIImage(cgImage: cgImage).oriented(orientation)
            if let corrected = perspectiveCorrect(ciImage, quad: quad) {
                let enhanced = autoEnhance(corrected)
                if let outputImage = convertToUIImage(enhanced) {
                    DispatchQueue.main.async { completion(outputImage) }
                    return
                }
            }
            DispatchQueue.main.async { completion(image) }
        }
    }

    private static func processImageInternal(_ image: UIImage, preferredQuad: NormalizedQuad?)
        -> UIImage
    {
        // 保留原始方向信息，避免 Vision 识别失败
        guard let cgImage = image.cgImage else { return image }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        // 将 CIImage 按照原始方向矫正，保证坐标系与 Vision 一致
        let ciImage = CIImage(cgImage: cgImage).oriented(orientation)

        // 1. 边缘检测（考虑方向）
        if let corners = detectRectangle(in: ciImage, orientation: orientation) {
            // 2. 透视矫正 + 裁剪，仅保留文档区域
            if let corrected = perspectiveCorrect(ciImage, corners: corners) {
                // 3. 自动提亮
                let enhanced = autoEnhance(corrected)
                if let outputImage = convertToUIImage(enhanced) {
                    return outputImage
                }
            }
        } else if let quad = preferredQuad,
            let corrected = perspectiveCorrect(ciImage, quad: quad)
        {
            let enhanced = autoEnhance(corrected)
            if let outputImage = convertToUIImage(enhanced) {
                return outputImage
            }
        }

        // 如果检测失败，至少进行提亮处理
        let enhanced = autoEnhance(ciImage)
        return convertToUIImage(enhanced) ?? image
    }

    /**
     * 使用Vision框架检测矩形
     */
    private static func detectRectangle(in image: CIImage, orientation: CGImagePropertyOrientation)
        -> VNRectangleObservation?
    {
        // 两段式检测：先用较严格参数，失败再用更宽松的参数以适配小票/细长文档
        let largePrimary = RectangleConfig(
            minAspect: 0.65, maxAspect: 1.8,
            minSize: 0.35, minConfidence: 0.45,
            quadratureTolerance: 22
        )

        let primary = RectangleConfig(
            minAspect: 0.35, maxAspect: 3.0,
            minSize: 0.15, minConfidence: 0.50,
            quadratureTolerance: 20
        )
        let fallback = RectangleConfig(
            minAspect: 0.10, maxAspect: 6.0,
            minSize: 0.07, minConfidence: 0.38,
            quadratureTolerance: 30
        )
        let wideFallback = RectangleConfig(
            minAspect: 0.06, maxAspect: 8.0,
            minSize: 0.04, minConfidence: 0.30,
            quadratureTolerance: 38
        )

        for config in [largePrimary, primary, fallback, wideFallback] {
            if let obs = performRectangleDetection(
                image: image, orientation: orientation, config: config)
            {
                return obs
            }
        }
        return nil
    }

    private struct RectangleConfig {
        let minAspect: Float
        let maxAspect: Float
        let minSize: Float
        let minConfidence: Float
        let quadratureTolerance: Float
    }

    private static func performRectangleDetection(
        image: CIImage,
        orientation: CGImagePropertyOrientation,
        config: RectangleConfig
    ) -> VNRectangleObservation? {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = config.minAspect
        request.maximumAspectRatio = config.maxAspect
        request.minimumSize = config.minSize
        request.minimumConfidence = config.minConfidence
        request.maximumObservations = 8
        request.quadratureTolerance = config.quadratureTolerance

        let handler = VNImageRequestHandler(ciImage: image, orientation: orientation, options: [:])
        try? handler.perform([request])
        guard let results = request.results as? [VNRectangleObservation], !results.isEmpty else {
            return nil
        }

        let best =
            results
            .filter { $0.confidence >= config.minConfidence }
            .max { lhs, rhs in
                score(for: lhs) < score(for: rhs)
            }

        return best ?? results.first
    }

    private static func score(for obs: VNRectangleObservation) -> Float {
        let area = obs.boundingBox.width * obs.boundingBox.height  // CGFloat
        let confidence = obs.confidence  // Float

        let center = CGPoint(x: 0.5, y: 0.5)
        let dx = obs.boundingBox.midX - center.x
        let dy = obs.boundingBox.midY - center.y
        let centerDist = CGFloat(hypot(dx, dy))
        let centerWeight = max(CGFloat(0.4), 1.0 - centerDist * 1.2)

        let aspect = max(
            obs.boundingBox.width / obs.boundingBox.height,
            obs.boundingBox.height / obs.boundingBox.width
        )
        let aspectPenalty: CGFloat = aspect > 4.5 ? 0.6 : (aspect > 3.5 ? 0.8 : 1.0)

        let areaBoost = min(Float(area) * 1.4 + 0.6, 3.0)
        return confidence * Float(area * centerWeight * aspectPenalty) * areaBoost
    }

    /**
     * 透视矫正
     */
    private static func perspectiveCorrect(_ image: CIImage, corners: VNRectangleObservation)
        -> CIImage?
    {
        let quad = NormalizedQuad(
            topLeft: corners.topLeft,
            topRight: corners.topRight,
            bottomRight: corners.bottomRight,
            bottomLeft: corners.bottomLeft
        )
        return perspectiveCorrect(image, quad: quad)
    }

    private static func perspectiveCorrect(_ image: CIImage, quad: NormalizedQuad) -> CIImage? {
        let imageSize = image.extent.size

        // 转换坐标系（Vision使用标准化坐标，原点在左下角）
        let topLeft = CGPoint(
            x: quad.topLeft.x * imageSize.width,
            y: (1 - quad.topLeft.y) * imageSize.height
        )
        let topRight = CGPoint(
            x: quad.topRight.x * imageSize.width,
            y: (1 - quad.topRight.y) * imageSize.height
        )
        let bottomRight = CGPoint(
            x: quad.bottomRight.x * imageSize.width,
            y: (1 - quad.bottomRight.y) * imageSize.height
        )
        let bottomLeft = CGPoint(
            x: quad.bottomLeft.x * imageSize.width,
            y: (1 - quad.bottomLeft.y) * imageSize.height
        )

        // 计算输出图片尺寸
        let width = max(
            distance(topLeft, topRight),
            distance(bottomLeft, bottomRight)
        )
        let height = max(
            distance(topLeft, bottomLeft),
            distance(topRight, bottomRight)
        )

        // 透视变换
        let perspectiveCorrection = CIFilter(name: "CIPerspectiveCorrection")
        perspectiveCorrection?.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
        perspectiveCorrection?.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
        perspectiveCorrection?.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")
        perspectiveCorrection?.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
        perspectiveCorrection?.setValue(image, forKey: kCIInputImageKey)

        guard let output = perspectiveCorrection?.outputImage else { return nil }

        // 矫正后的图像可能带有偏移/黑边，这里将原点平移到 0,0 并裁剪到文档宽高
        let translated = output.transformed(
            by: CGAffineTransform(
                translationX: -output.extent.origin.x,
                y: -output.extent.origin.y
            ))

        let targetWidth = max(width, 1)
        let targetHeight = max(height, 1)
        let cropRect = CGRect(origin: .zero, size: CGSize(width: targetWidth, height: targetHeight))

        return translated.cropped(to: cropRect)
    }

    /**
     * 自动提亮和对比度优化
     */
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

    /**
     * 转换为UIImage
     */
    private static func convertToUIImage(_ ciImage: CIImage) -> UIImage? {
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    /**
     * 计算两点距离
     */
    private static func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }
}

// MARK: - Orientation helper
extension CGImagePropertyOrientation {
    fileprivate init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}
