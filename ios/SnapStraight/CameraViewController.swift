import AVFoundation
import UIKit
import Vision

/// 相机拍摄ViewController
/// 全屏取景，一键拍照，自动进入处理流程
class CameraViewController: UIViewController {

    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let videoDataOutputQueue = DispatchQueue(label: "com.snapstraight.camera.video")
    private var detectionOverlay = CAShapeLayer()
    private var isProcessingFrame = false
    private let detectionHintLabel = UILabel()
    private var detectionHintWorkItem: DispatchWorkItem?
    private var hasDetectedRectangle = false
    private var isSessionConfigured = false
    private var lastNormalizedQuad: NormalizedQuad?

    // Auto-Capture Properties
    private var stabilityCounter = 0
    private let stabilityThreshold = 25  // Increase to approx 0.8s for better precision
    private var isAutoCapturing = false
    private let progressLayer = CAShapeLayer()

    private let backButton = UIButton(type: .system)
    private let captureButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        checkCameraAuthorization()
        setupUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateProgressFrame()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if isSessionConfigured {
            captureSession?.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }

    private func checkCameraAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCamera()
                    } else {
                        self?.handleCameraUnavailable(
                            reason: NSLocalizedString("camera_permission_denied", comment: ""))
                    }
                }
            }
        default:
            handleCameraUnavailable(
                reason: NSLocalizedString("camera_permission_denied", comment: ""))
        }
    }

    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo

        guard
            let backCamera = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: backCamera),
            let session = captureSession
        else {
            handleCameraUnavailable(reason: NSLocalizedString("camera_unavailable", comment: ""))
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        } else {
            handleCameraUnavailable(reason: NSLocalizedString("camera_unavailable", comment: ""))
            return
        }

        photoOutput = AVCapturePhotoOutput()
        if let output = photoOutput, session.canAddOutput(output) {
            session.addOutput(output)
            // 启用高分辨率拍照与质量优先
            output.isHighResolutionCaptureEnabled = true
            if output.isLivePhotoCaptureSupported {
                output.isLivePhotoCaptureEnabled = false
            }
            if #available(iOS 13.0, *) {
                output.maxPhotoQualityPrioritization = .quality
            }
        } else {
            handleCameraUnavailable(reason: NSLocalizedString("camera_unavailable", comment: ""))
            return
        }

        // 视频输出用于实时边缘检测
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            // Explicitly set video orientation to portrait to align with Vision coordinates
            if let connection = videoOutput.connection(with: .video),
                connection.isVideoOrientationSupported
            {
                connection.videoOrientation = .portrait
            }
            self.videoOutput = videoOutput
        } else {
            handleCameraUnavailable(reason: NSLocalizedString("camera_unavailable", comment: ""))
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.frame = view.bounds
        previewLayer?.contentsScale = UIScreen.main.scale
        if let previewLayer = previewLayer {
            view.layer.addSublayer(previewLayer)
        }

        setupDetectionOverlay()
        isSessionConfigured = true
    }

    private func handleCameraUnavailable(reason: String) {
        isSessionConfigured = false
        updateCaptureButtonState(enabled: false)
        let alert = UIAlertController(
            title: NSLocalizedString("camera_error_title", comment: ""),
            message: reason,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default))
        // 避免在 view 未加载完时 present
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.presentedViewController == nil else { return }
            self.present(alert, animated: true)
        }
    }

    private func setupDetectionOverlay() {
        detectionOverlay.strokeColor = UIColor.systemYellow.cgColor
        detectionOverlay.fillColor = UIColor.clear.cgColor
        detectionOverlay.lineWidth = 3
        detectionOverlay.lineJoin = .round
        detectionOverlay.frame = view.bounds
        // 已根据用户反馈移除黄色框显示，仅保留后台检测逻辑与进度条
        // view.layer.addSublayer(detectionOverlay)

        setupProgressLayer()
    }

    private func setupUI() {
        view.backgroundColor = .black

        // 返回按钮
        backButton.setTitle(NSLocalizedString("btn_back", comment: ""), for: .normal)
        backButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        backButton.setTitleColor(.white, for: .normal)
        backButton.backgroundColor = UIColor(white: 0, alpha: 0.5)
        backButton.layer.cornerRadius = 8
        backButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backButton)

        // 拍照按钮
        captureButton.backgroundColor = UIColor(red: 0.96, green: 0.26, blue: 0.21, alpha: 1.0)  // #F44336
        captureButton.layer.cornerRadius = 50
        captureButton.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(captureButton)
        updateCaptureButtonState(enabled: false)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -48),
            captureButton.widthAnchor.constraint(equalToConstant: 100),
            captureButton.heightAnchor.constraint(equalToConstant: 100),
        ])

        setupDetectionHint()
    }

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func captureTapped() {
        guard let output = photoOutput else { return }
        let settings = AVCapturePhotoSettings()
        settings.isHighResolutionPhotoEnabled = true
        if #available(iOS 13.0, *) {
            settings.photoQualityPrioritization = .quality
        }
        settings.flashMode = .off
        if output.isAutoStillImageStabilizationSupported {
            settings.isAutoStillImageStabilizationEnabled = true
        }
        output.capturePhoto(with: settings, delegate: self)
    }

    private func updateCaptureButtonState(enabled: Bool) {
        captureButton.isEnabled = enabled
        if enabled {
            captureButton.alpha = 1.0
            captureButton.transform = .identity
        } else {
            captureButton.alpha = 0.5
            captureButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard let imageData = photo.fileDataRepresentation(),
            let image = UIImage(data: imageData)
        else {
            return
        }

        // 进入结果页：原图 + 初始四边形，支持用户调整
        let resultVC = ResultViewController(
            originalImage: image,
            initialQuad: lastNormalizedQuad?.asProcessorQuad()
        )

        // 所有 UI 操作必须在主线程执行，避免导航栈卡住导致“返回”无响应
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.navigationController?.pushViewController(resultVC, animated: true)

            // Reset state
            self.isAutoCapturing = false
            self.stabilityCounter = 0
            self.updateProgressLayer()
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Ensure connection orientation is correct (double check)
        if connection.videoOrientation != .portrait {
            connection.videoOrientation = .portrait
        }
        guard !isProcessingFrame,
            let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { return }
        isProcessingFrame = true
        // Input is now guaranteed portrait, so use .up to match
        let observation = detectRectangle(in: pixelBuffer, orientation: .up)
        DispatchQueue.main.async { [weak self] in
            self?.updateOverlay(with: observation)
        }
        isProcessingFrame = false
    }
}

// MARK: - Overlay helpers
extension CameraViewController {
    fileprivate func updateOverlay(with observation: VNRectangleObservation?) {
        guard let previewLayer = previewLayer else { return }
        guard let obs = observation else {
            detectionOverlay.path = nil
            showDetectionHint()
            hasDetectedRectangle = false
            updateCaptureButtonState(enabled: false)
            lastNormalizedQuad = nil

            // Reset auto capture
            stabilityCounter = 0
            updateProgressLayer()
            return
        }
        let smoothed = smoothQuad(with: obs)
        let path = UIBezierPath()

        // Vision coordinates are normalized with (0,0) at bottom-left.
        // CaptureDevicePoint coordinates are normalized with (0,0) at top-left.
        // We need to flip Y.
        func flipY(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: 1 - p.y) }

        let tl = previewLayer.layerPointConverted(fromCaptureDevicePoint: flipY(smoothed.topLeft))
        let tr = previewLayer.layerPointConverted(fromCaptureDevicePoint: flipY(smoothed.topRight))
        let br = previewLayer.layerPointConverted(
            fromCaptureDevicePoint: flipY(smoothed.bottomRight))
        let bl = previewLayer.layerPointConverted(
            fromCaptureDevicePoint: flipY(smoothed.bottomLeft))
        path.move(to: tl)
        path.addLine(to: tr)
        path.addLine(to: br)
        path.addLine(to: bl)
        path.close()
        // detectionOverlay.path = path.cgPath
        hideDetectionHint()
        if !hasDetectedRectangle {
            hasDetectedRectangle = true
            updateCaptureButtonState(enabled: true)
        }

        // Auto Capture Logic
        if !isAutoCapturing {
            if stabilityCounter >= stabilityThreshold {
                triggerAutoCapture()
            } else {
                updateProgressLayer()
            }
        }
    }

    private func triggerAutoCapture() {
        guard !isAutoCapturing else { return }
        isAutoCapturing = true
        stabilityCounter = 0
        updateProgressLayer()

        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        guard let output = photoOutput else { return }
        let settings = AVCapturePhotoSettings()
        settings.isHighResolutionPhotoEnabled = true
        if #available(iOS 13.0, *) {
            settings.photoQualityPrioritization = .quality
        }
        settings.flashMode = .off
        if output.isAutoStillImageStabilizationSupported {
            settings.isAutoStillImageStabilizationEnabled = true
        }
        output.capturePhoto(with: settings, delegate: self)
    }

    private func smoothQuad(with obs: VNRectangleObservation) -> NormalizedQuad {
        let newQuad = NormalizedQuad(
            topLeft: obs.topLeft,
            topRight: obs.topRight,
            bottomRight: obs.bottomRight,
            bottomLeft: obs.bottomLeft
        )

        guard let last = lastNormalizedQuad else {
            lastNormalizedQuad = newQuad
            return newQuad
        }

        // 若跳变过大（中心移动超过 0.3 的归一化距离），直接重置，避免锁定错误目标
        let lastCenter = last.center
        let newCenter = newQuad.center
        let dx = newCenter.x - lastCenter.x
        let dy = newCenter.y - lastCenter.y
        let moveDist = sqrt(dx * dx + dy * dy)

        if moveDist > 0.3 {
            lastNormalizedQuad = newQuad
            stabilityCounter = 0  // Reset stability if moved too much
            return newQuad
        }

        // Check for stability
        if moveDist < 0.02 {  // Very stable
            stabilityCounter += 1
        } else if moveDist > 0.05 {  // Slightly moving, pause or reset? let's reset to be strict
            stabilityCounter = 0  // max(0, stabilityCounter - 1)
        }

        let alpha: CGFloat = 0.3  // 越小越平滑
        let blended = NormalizedQuad(
            topLeft: last.topLeft.lerp(to: newQuad.topLeft, alpha: alpha),
            topRight: last.topRight.lerp(to: newQuad.topRight, alpha: alpha),
            bottomRight: last.bottomRight.lerp(to: newQuad.bottomRight, alpha: alpha),
            bottomLeft: last.bottomLeft.lerp(to: newQuad.bottomLeft, alpha: alpha)
        )
        lastNormalizedQuad = blended
        return blended
    }

    fileprivate struct NormalizedQuad {
        let topLeft: CGPoint
        let topRight: CGPoint
        let bottomRight: CGPoint
        let bottomLeft: CGPoint

        var center: CGPoint {
            CGPoint(
                x: (topLeft.x + topRight.x + bottomRight.x + bottomLeft.x) * 0.25,
                y: (topLeft.y + topRight.y + bottomRight.y + bottomLeft.y) * 0.25
            )
        }
    }

    private func setupDetectionHint() {
        detectionHintLabel.text = NSLocalizedString("hint_no_edges", comment: "")
        detectionHintLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        detectionHintLabel.textColor = .white
        detectionHintLabel.backgroundColor = UIColor(white: 0, alpha: 0.65)
        detectionHintLabel.textAlignment = .center
        detectionHintLabel.layer.cornerRadius = 12
        detectionHintLabel.layer.masksToBounds = true
        detectionHintLabel.alpha = 0
        detectionHintLabel.numberOfLines = 0
        detectionHintLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(detectionHintLabel)

        NSLayoutConstraint.activate([
            detectionHintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            detectionHintLabel.bottomAnchor.constraint(
                equalTo: captureButton.topAnchor, constant: -24),
            detectionHintLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            detectionHintLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: view.trailingAnchor, constant: -24),
        ])
    }

    private func showDetectionHint() {
        detectionHintWorkItem?.cancel()
        UIView.animate(withDuration: 0.18) { [weak self] in
            self?.detectionHintLabel.alpha = 1
        }

        let work = DispatchWorkItem { [weak self] in
            UIView.animate(withDuration: 0.18) {
                self?.detectionHintLabel.alpha = 0
            }
        }
        detectionHintWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }

    private func hideDetectionHint() {
        detectionHintWorkItem?.cancel()
        UIView.animate(withDuration: 0.18) { [weak self] in
            self?.detectionHintLabel.alpha = 0
        }
    }
}

// MARK: - Orientation mapping
extension CGImagePropertyOrientation {
    fileprivate init(deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portraitUpsideDown: self = .left
        case .landscapeLeft: self = .up
        case .landscapeRight: self = .down
        default: self = .right
        }
    }
}

// MARK: - Vision detection helpers
extension CameraViewController {
    private struct RectangleConfig {
        let minAspect: Float
        let maxAspect: Float
        let minSize: Float
        let minConfidence: Float
        let quadratureTolerance: Float
    }

    fileprivate func detectRectangle(
        in pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation
    ) -> VNRectangleObservation? {
        // 进一步放宽限制，允许更大幅度的透视变形和更小的目标
        let largePrimary = RectangleConfig(
            minAspect: 0.5, maxAspect: 2.0,
            minSize: 0.25, minConfidence: 0.45,
            quadratureTolerance: 45
        )
        let primary = RectangleConfig(
            minAspect: 0.2, maxAspect: 4.0,
            minSize: 0.1, minConfidence: 0.4,
            quadratureTolerance: 45
        )
        let fallback = RectangleConfig(
            minAspect: 0.05, maxAspect: 10.0,
            minSize: 0.05, minConfidence: 0.3,
            quadratureTolerance: 45
        )

        for config in [largePrimary, primary, fallback] {
            if let obs = performRectangleDetection(
                pixelBuffer: pixelBuffer,
                orientation: orientation,
                config: config
            ) {
                return obs
            }
        }
        return nil
    }

    private func performRectangleDetection(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        config: RectangleConfig
    ) -> VNRectangleObservation? {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = config.minAspect
        request.maximumAspectRatio = config.maxAspect
        request.minimumSize = config.minSize
        request.minimumConfidence = config.minConfidence
        request.maximumObservations = 16  // Increase to check more candidates
        request.quadratureTolerance = config.quadratureTolerance

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: orientation,
            options: [:]
        )
        try? handler.perform([request])

        guard let results = request.results as? [VNRectangleObservation], !results.isEmpty else {
            return nil
        }

        // 选出面积大且置信度高的矩形，减少乱跳
        let best =
            results
            .filter { $0.confidence >= config.minConfidence }
            .max { lhs, rhs in
                score(for: lhs) < score(for: rhs)
            }

        return best ?? results.first
    }

    private func score(for obs: VNRectangleObservation) -> Float {
        let area = obs.boundingBox.width * obs.boundingBox.height  // CGFloat
        let confidence = obs.confidence

        // 中心权重：越靠屏幕中心得分越高，最大约 1.0，边缘衰减
        let center = CGPoint(x: 0.5, y: 0.5)
        let dx = obs.boundingBox.midX - center.x
        let dy = obs.boundingBox.midY - center.y
        let centerDist = CGFloat(hypot(dx, dy))
        let centerWeight = max(CGFloat(0.4), 1.0 - centerDist * 1.2)

        // 纵横比惩罚：过于极端的细长形降权
        let aspect = max(
            obs.boundingBox.width / obs.boundingBox.height,
            obs.boundingBox.height / obs.boundingBox.width
        )
        let aspectPenalty: CGFloat = aspect > 4.5 ? 0.6 : (aspect > 3.5 ? 0.8 : 1.0)

        // 面积权重：大幅提升面积权重，避免背景中的小矩形干扰
        let areaBoost = pow(Float(area), 0.7) * 2.0

        // 形状权重：越接近矩形（通过 Vision 内部评分或长宽比合理性）
        // 这里简单用长宽比分段
        let aspectWeight: Float = (aspect > 1.0 && aspect < 1.6) ? 1.2 : 1.0  // 接近 A4 比例加权

        return confidence * Float(centerWeight * aspectPenalty) * areaBoost * aspectWeight
    }
}

// MARK: - Auto Capture UI
extension CameraViewController {
    fileprivate func setupProgressLayer() {
        progressLayer.strokeColor = UIColor.green.cgColor
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.lineWidth = 5
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0
        progressLayer.frame = captureButton.bounds

        // Create circular path matching capture button
        let path = UIBezierPath(ovalIn: captureButton.bounds.insetBy(dx: -5, dy: -5))
        progressLayer.path = path.cgPath

        // Add to capture button's superview so it sits around it
        captureButton.superview?.layer.addSublayer(progressLayer)
        // Center it relative to capture button
        // Since we added it to superview, we need to correct position
        // Ideally add it to captureButton but it clips. Let's add top level.
    }

    fileprivate func updateProgressLayer() {
        // Re-layout if needed in viewDidLayoutSubviews, but for now just update stroke
        let progress = CGFloat(stabilityCounter) / CGFloat(stabilityThreshold)
        progressLayer.strokeEnd = progress

        if progress > 0 {
            progressLayer.strokeColor =
                (stabilityCounter >= stabilityThreshold)
                ? UIColor.white.cgColor : UIColor.green.cgColor
        }
    }

    fileprivate func updateProgressFrame() {
        progressLayer.frame = captureButton.frame.insetBy(dx: -8, dy: -8)
        progressLayer.path = UIBezierPath(ovalIn: progressLayer.bounds).cgPath
    }
}

extension CGPoint {
    fileprivate func lerp(to: CGPoint, alpha: CGFloat) -> CGPoint {
        CGPoint(
            x: self.x * (1 - alpha) + to.x * alpha,
            y: self.y * (1 - alpha) + to.y * alpha
        )
    }
}

extension CameraViewController.NormalizedQuad {
    fileprivate func asProcessorQuad() -> ImageProcessor.NormalizedQuad {
        ImageProcessor.NormalizedQuad(
            topLeft: topLeft,
            topRight: topRight,
            bottomRight: bottomRight,
            bottomLeft: bottomLeft
        )
    }
}
