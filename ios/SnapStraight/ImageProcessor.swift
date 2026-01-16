import UIKit
import Vision
import CoreImage

/**
 * 图像处理核心类
 * 实现边缘检测、透视矫正、自动裁剪、亮度优化等功能
 */
class ImageProcessor {
    
    /**
     * 处理图片主流程
     */
    static func processImage(_ image: UIImage, completion: @escaping (UIImage) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let processed = processImageInternal(image)
            DispatchQueue.main.async {
                completion(processed)
            }
        }
    }
    
    private static func processImageInternal(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else {
            return image
        }
        
        // 1. 边缘检测
        if let corners = detectRectangle(in: ciImage) {
            // 2. 透视矫正
            if let corrected = perspectiveCorrect(ciImage, corners: corners) {
                // 3. 自动提亮
                let enhanced = autoEnhance(corrected)
                if let outputImage = convertToUIImage(enhanced) {
                    return outputImage
                }
            }
        }
        
        // 如果检测失败，至少进行提亮处理
        let enhanced = autoEnhance(ciImage)
        return convertToUIImage(enhanced) ?? image
    }
    
    /**
     * 使用Vision框架检测矩形
     */
    private static func detectRectangle(in image: CIImage) -> VNRectangleObservation? {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.3
        request.maximumAspectRatio = 3.0
        request.minimumSize = 0.3
        request.maximumObservations = 1
        
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        try? handler.perform([request])
        
        return request.results?.first
    }
    
    /**
     * 透视矫正
     */
    private static func perspectiveCorrect(_ image: CIImage, corners: VNRectangleObservation) -> CIImage? {
        let imageSize = image.extent.size
        
        // 转换坐标系（Vision使用标准化坐标，原点在左下角）
        let topLeft = CGPoint(
            x: corners.topLeft.x * imageSize.width,
            y: (1 - corners.topLeft.y) * imageSize.height
        )
        let topRight = CGPoint(
            x: corners.topRight.x * imageSize.width,
            y: (1 - corners.topRight.y) * imageSize.height
        )
        let bottomRight = CGPoint(
            x: corners.bottomRight.x * imageSize.width,
            y: (1 - corners.bottomRight.y) * imageSize.height
        )
        let bottomLeft = CGPoint(
            x: corners.bottomLeft.x * imageSize.width,
            y: (1 - corners.bottomLeft.y) * imageSize.height
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
        
        return perspectiveCorrection?.outputImage
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
