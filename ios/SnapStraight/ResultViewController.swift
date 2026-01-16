import Photos
import UIKit

/// 结果展示ViewController
/// 显示拍摄原图 + 可调四边形，拉平预览与保存
class ResultViewController: UIViewController {

    private let originalImage: UIImage
    private let initialQuad: ImageProcessor.NormalizedQuad?

    private let imageView = UIImageView()
    private let overlayView = QuadOverlayView()
    private let backButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)

    private var hasConfigured = false

    init(originalImage: UIImage, initialQuad: ImageProcessor.NormalizedQuad?) {
        self.originalImage = originalImage
        self.initialQuad = initialQuad
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Ensure frames are finalized before configuring the overlay
        if !hasConfigured && imageView.bounds.width > 0 {
            overlayView.configure(for: imageView, image: originalImage, initialQuad: initialQuad)
            hasConfigured = true
        }
    }

    private func setupUI() {
        view.backgroundColor = .white

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

        // 图片预览
        imageView.image = originalImage
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true // Required for subview interactions
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)

        // 覆盖层（四边形可拖拽） - 改为 imageView 的子视图，确保坐标系绝对对齐
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        imageView.addSubview(overlayView)


        saveButton.setTitle(NSLocalizedString("btn_save", comment: "保存"), for: .normal)
        saveButton.titleLabel?.font = UIFont.systemFont(ofSize: 22, weight: .medium)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.backgroundColor = UIColor(red: 0.96, green: 0.26, blue: 0.21, alpha: 1.0)
        saveButton.layer.cornerRadius = 12
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(saveButton)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            imageView.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            imageView.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -16),

            overlayView.topAnchor.constraint(equalTo: imageView.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),

            saveButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 48),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -48),
            saveButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            saveButton.heightAnchor.constraint(equalToConstant: 54),
        ])
    }

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }


    @objc private func saveTapped() {
        guard let quad = overlayView.currentNormalizedQuad(in: imageView, image: originalImage)
        else { return }
        
        // Show processing alert
        let alert = UIAlertController(title: nil, message: NSLocalizedString("processing", comment: ""), preferredStyle: .alert)
        present(alert, animated: true)

        ImageProcessor.processImageWithQuad(originalImage, quad: quad) { [weak self] processedImage in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: processedImage)
            }) { [weak self] success, error in
                DispatchQueue.main.async {
                    alert.dismiss(animated: true) {
                        if success {
                            self?.showSaveSuccess()
                        } else {
                            self?.showSaveError()
                        }
                    }
                }
            }
        }
    }

    private func showSaveSuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        let alert = UIAlertController(
            title: nil,
            message: NSLocalizedString("save_success", comment: ""),
            preferredStyle: .alert
        )
        present(alert, animated: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            alert.dismiss(animated: true)
            self?.navigationController?.popToRootViewController(animated: true)
        }
    }

    private func showSaveError() {
        let alert = UIAlertController(
            title: nil,
            message: NSLocalizedString("save_failed", comment: ""),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - QuadOverlayView: 可拖拽四点覆盖层
private class QuadOverlayView: UIView {
    private let shape = CAShapeLayer()
    private var handles: [UIView] = []
    private var imageRect: CGRect = .zero
    private var currentPoints: [CGPoint] = []  // in view coords

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        shape.strokeColor = UIColor.systemYellow.cgColor
        shape.fillColor = UIColor.clear.cgColor
        shape.lineWidth = 3
        layer.addSublayer(shape)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(
        for imageView: UIImageView, image: UIImage, initialQuad: ImageProcessor.NormalizedQuad?
    ) {
        imageRect = imageView.imageDisplayRect
        handles.forEach { $0.removeFromSuperview() }
        handles = []

        // 默认矩形：图片内边距 10%
        let defaultQuad = ImageProcessor.NormalizedQuad(
            topLeft: CGPoint(x: 0.1, y: 0.9),
            topRight: CGPoint(x: 0.9, y: 0.9),
            bottomRight: CGPoint(x: 0.9, y: 0.1),
            bottomLeft: CGPoint(x: 0.1, y: 0.1)
        )
        let quad = initialQuad ?? defaultQuad

        currentPoints = [quad.topLeft, quad.topRight, quad.bottomRight, quad.bottomLeft].map { p in
            CGPoint(
                x: imageRect.origin.x + p.x * imageRect.width,
                y: imageRect.origin.y + (1 - p.y) * imageRect.height
            )
        }

        for idx in 0..<4 {
            let handle = UIView(frame: CGRect(x: 0, y: 0, width: 28, height: 28))
            handle.backgroundColor = UIColor.systemYellow
            handle.layer.cornerRadius = 14
            handle.layer.borderWidth = 2
            handle.layer.borderColor = UIColor.black.withAlphaComponent(0.6).cgColor
            handle.center = currentPoints[idx]
            handle.addGestureRecognizer(
                UIPanGestureRecognizer(target: self, action: #selector(panned(_:))))
            addSubview(handle)
            handles.append(handle)
        }
        redraw()
    }

    @objc private func panned(_ gr: UIPanGestureRecognizer) {
        guard let idx = handles.firstIndex(where: { $0 === gr.view }) else { return }
        let delta = gr.translation(in: self)
        gr.setTranslation(.zero, in: self)
        var newCenter = handles[idx].center.applying(
            CGAffineTransform(translationX: delta.x, y: delta.y))
        // 限制在图片显示区域内
        newCenter.x = min(max(newCenter.x, imageRect.minX), imageRect.maxX)
        newCenter.y = min(max(newCenter.y, imageRect.minY), imageRect.maxY)
        handles[idx].center = newCenter
        currentPoints[idx] = newCenter
        redraw()
    }

    private func redraw() {
        guard currentPoints.count == 4 else { return }
        let path = UIBezierPath()
        path.move(to: currentPoints[0])
        path.addLine(to: currentPoints[1])
        path.addLine(to: currentPoints[2])
        path.addLine(to: currentPoints[3])
        path.close()
        shape.path = path.cgPath
    }

    func currentNormalizedQuad(in imageView: UIImageView, image: UIImage) -> ImageProcessor
        .NormalizedQuad?
    {
        guard currentPoints.count == 4 else { return nil }
        let rect = imageView.imageDisplayRect
        func norm(_ p: CGPoint) -> CGPoint {
            let nx = (p.x - rect.origin.x) / rect.width
            let ny = 1 - (p.y - rect.origin.y) / rect.height
            return CGPoint(x: nx, y: ny)
        }
        return ImageProcessor.NormalizedQuad(
            topLeft: norm(currentPoints[0]),
            topRight: norm(currentPoints[1]),
            bottomRight: norm(currentPoints[2]),
            bottomLeft: norm(currentPoints[3])
        )
    }
}

// MARK: - UIImageView 辅助：计算 scaleAspectFit 的真实显示区域
extension UIImageView {
    fileprivate var imageDisplayRect: CGRect {
        guard let image = image else { return bounds }
        let viewSize = bounds.size
        let imgSize = image.size
        let scale = min(viewSize.width / imgSize.width, viewSize.height / imgSize.height)
        let width = imgSize.width * scale
        let height = imgSize.height * scale
        let x = (viewSize.width - width) * 0.5
        let y = (viewSize.height - height) * 0.5
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
