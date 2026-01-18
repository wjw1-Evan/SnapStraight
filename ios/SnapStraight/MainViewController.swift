import AVFoundation
import Photos
import UIKit

/// 主界面ViewController
/// 仅包含拍照和选图两个核心功能入口
class MainViewController: UIViewController {

    // UI组件
    private let appTitleLabel = UILabel()
    private let appSubtitleLabel = UILabel()
    private let takePhotoButton = UIButton(type: .system)
    private let selectPhotoButton = UIButton(type: .system)
    private let buttonsStack = UIStackView()
    private let usageLabel = UILabel()
    private let usagePrivacyLabel = UILabel()
    private let usageContainer = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let usageIconView = UIImageView()
    private var gradientButtons: [(button: UIButton, colors: [UIColor])] = []
    private var buttonSizeConstraints: [NSLayoutConstraint] = []
    private var usageTopConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateButtonsIntro()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateGradientFrames()
    }

    private func setupUI() {
        // 使用系统背景色以支持浅色/深色模式
        view.backgroundColor = .systemBackground

        // 顶部标题区域
        appTitleLabel.text = NSLocalizedString("app_name", comment: "")
        appTitleLabel.font = UIFont.preferredFont(forTextStyle: .largeTitle)
        appTitleLabel.adjustsFontForContentSizeCategory = true
        appTitleLabel.textColor = .label
        appTitleLabel.textAlignment = .center
        appTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(appTitleLabel)

        appSubtitleLabel.text = NSLocalizedString("app_name_en", comment: "")
        appSubtitleLabel.font = UIFont.preferredFont(forTextStyle: .title2)
        appSubtitleLabel.adjustsFontForContentSizeCategory = true
        appSubtitleLabel.textColor = .secondaryLabel
        appSubtitleLabel.textAlignment = .center
        appSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(appSubtitleLabel)

        // 按钮组
        configureButton(takePhotoButton,
                title: NSLocalizedString("btn_take_photo", comment: ""),
                systemImage: "camera.fill",
                gradientColors: [UIColor.systemBlue, UIColor.systemIndigo])

        configureButton(selectPhotoButton,
                title: NSLocalizedString("btn_select_photo", comment: ""),
                systemImage: "photo.fill",
                gradientColors: [UIColor.systemGreen, UIColor.systemTeal])

        buttonsStack.axis = .horizontal
        buttonsStack.alignment = .center
        buttonsStack.spacing = 20
        buttonsStack.distribution = .equalSpacing
        buttonsStack.translatesAutoresizingMaskIntoConstraints = false
        buttonsStack.addArrangedSubview(takePhotoButton)
        buttonsStack.addArrangedSubview(selectPhotoButton)
        view.addSubview(buttonsStack)

        // 使用方法说明（显示在两个按钮下方）
        usageLabel.text = NSLocalizedString("usage_content", comment: "")
        usageLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        usageLabel.adjustsFontForContentSizeCategory = true
        usageLabel.textColor = .secondaryLabel
        usageLabel.textAlignment = .left
        usageLabel.numberOfLines = 0

        usagePrivacyLabel.text = "隐私保护：处理全程在本机进行，您的图片与文件不会被上传到任何服务器。"
        usagePrivacyLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        usagePrivacyLabel.adjustsFontForContentSizeCategory = true
        usagePrivacyLabel.textColor = .tertiaryLabel
        usagePrivacyLabel.textAlignment = .left
        usagePrivacyLabel.numberOfLines = 0

        usageIconView.image = UIImage(systemName: "info.circle.fill")
        usageIconView.tintColor = .tertiaryLabel
        usageIconView.contentMode = .scaleAspectFit
        usageIconView.translatesAutoresizingMaskIntoConstraints = false

        usageContainer.layer.cornerRadius = 16
        usageContainer.clipsToBounds = true
        usageContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(usageContainer)

        let textStack = UIStackView(arrangedSubviews: [usageLabel, usagePrivacyLabel])
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 6
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let usageStack = UIStackView(arrangedSubviews: [usageIconView, textStack])
        usageStack.axis = .horizontal
        usageStack.alignment = .center
        usageStack.spacing = 10
        usageStack.isLayoutMarginsRelativeArrangement = true
        usageStack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)
        usageStack.translatesAutoresizingMaskIntoConstraints = false
        usageContainer.contentView.addSubview(usageStack)

        // 布局约束
        let usageTop = usageContainer.topAnchor.constraint(equalTo: buttonsStack.bottomAnchor, constant: 20)
        usageTopConstraint = usageTop

        NSLayoutConstraint.activate([
            // 标题
            appTitleLabel.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            appTitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            appSubtitleLabel.topAnchor.constraint(equalTo: appTitleLabel.bottomAnchor, constant: 8),
            appSubtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // 按钮组
            buttonsStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            buttonsStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            buttonsStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            buttonsStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),

            // 使用方法说明
            usageTop,
            usageContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            usageContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            usageContainer.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),

            usageStack.topAnchor.constraint(equalTo: usageContainer.contentView.topAnchor),
            usageStack.leadingAnchor.constraint(equalTo: usageContainer.contentView.leadingAnchor),
            usageStack.trailingAnchor.constraint(equalTo: usageContainer.contentView.trailingAnchor),
            usageStack.bottomAnchor.constraint(equalTo: usageContainer.contentView.bottomAnchor),

            usageIconView.widthAnchor.constraint(equalToConstant: 22),
            usageIconView.heightAnchor.constraint(equalToConstant: 22),
        ])

        updateAdaptiveLayout(for: view.bounds.size, traitCollection: traitCollection)
    }

    private func configureButton(
        _ button: UIButton,
        title: String,
        systemImage: String,
        gradientColors: [UIColor]
    ) {
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            var attributed = AttributedString(title)
            attributed.font = .systemFont(ofSize: 20, weight: .semibold)
            config.attributedTitle = attributed
            config.image = UIImage(systemName: systemImage)
            config.imagePlacement = .top
            config.imagePadding = 8
            config.baseForegroundColor = .white
            config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)
            config.cornerStyle = .capsule
            button.configuration = config
        } else {
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
            button.setTitleColor(.white, for: .normal)
            button.contentEdgeInsets = UIEdgeInsets(top: 16, left: 18, bottom: 16, right: 18)
        }

        button.backgroundColor = .clear
        button.layer.cornerRadius = 28
        button.layer.masksToBounds = false
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.25
        button.layer.shadowRadius = 10
        button.layer.shadowOffset = CGSize(width: 0, height: 8)
        button.accessibilityLabel = title

        addHighlightAnimation(to: button)
        addGradient(to: button, colors: gradientColors)

        if button === takePhotoButton {
            button.addTarget(self, action: #selector(takePhotoTapped), for: .touchUpInside)
        } else if button === selectPhotoButton {
            button.addTarget(self, action: #selector(selectPhotoTapped), for: .touchUpInside)
        }

        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
    }

    private func addGradient(to button: UIButton, colors: [UIColor]) {
        gradientButtons.append((button: button, colors: colors))
        let layer = CAGradientLayer()
        layer.colors = colors.map { $0.cgColor }
        layer.startPoint = CGPoint(x: 0, y: 0)
        layer.endPoint = CGPoint(x: 1, y: 1)
        layer.frame = button.bounds
        layer.cornerRadius = button.layer.cornerRadius
        layer.name = "gradient"
        if let old = button.layer.sublayers?.first(where: { $0.name == "gradient" }) {
            old.removeFromSuperlayer()
        }
        button.layer.insertSublayer(layer, at: 0)
    }

    private func updateGradientFrames() {
        for (button, colors) in gradientButtons {
            if let layer = button.layer.sublayers?.first(where: { $0.name == "gradient" }) as? CAGradientLayer {
                layer.frame = button.bounds
                layer.cornerRadius = button.layer.cornerRadius
            } else {
                addGradient(to: button, colors: colors)
            }
        }
    }

    private func addHighlightAnimation(to button: UIButton) {
        button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: [.touchDown, .touchDragEnter])
        button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchCancel, .touchDragExit])
    }

    @objc private func takePhotoTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        checkCameraPermission { [weak self] granted in
            if granted {
                self?.openCamera()
            } else {
                self?.showPermissionAlert(
                    message: NSLocalizedString("permission_camera", comment: ""))
            }
        }
    }

    @objc private func selectPhotoTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        checkPhotoLibraryPermission { [weak self] granted in
            if granted {
                self?.openPhotoLibrary()
            } else {
                self?.showPermissionAlert(
                    message: NSLocalizedString("permission_storage", comment: ""))
            }
        }
    }

    private func checkCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        default:
            completion(false)
        }
    }

    private func checkPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized, .limited:
            completion(true)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    completion(status == .authorized || status == .limited)
                }
            }
        default:
            completion(false)
        }
    }

    private func openCamera() {
        let cameraVC = CameraViewController()
        navigationController?.pushViewController(cameraVC, animated: true)
    }

    private func openPhotoLibrary() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        picker.allowsEditing = false
        present(picker, animated: true)
    }

    private func showPermissionAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default))
        present(alert, animated: true)
    }

    private func animateButtonsIntro() {
        let targets = [takePhotoButton, selectPhotoButton]
        targets.forEach { $0.transform = CGAffineTransform(scaleX: 0.92, y: 0.92) }
        UIView.animate(withDuration: 0.6,
                       delay: 0,
                       usingSpringWithDamping: 0.6,
                       initialSpringVelocity: 0.6,
                       options: [.allowUserInteraction, .beginFromCurrentState]) {
            targets.forEach { $0.transform = .identity }
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.verticalSizeClass != previousTraitCollection?.verticalSizeClass ||
            traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass {
            updateAdaptiveLayout(for: view.bounds.size, traitCollection: traitCollection)
        }
    }

    private func updateAdaptiveLayout(for size: CGSize, traitCollection: UITraitCollection) {
        // 始终保持水平排布，但根据屏幕宽度微调间距和尺寸，避免窄屏拥挤
        let isVeryNarrow = size.width < 360
        let spacing: CGFloat = isVeryNarrow ? 12 : 18
        buttonsStack.axis = .horizontal
        buttonsStack.spacing = spacing

        buttonSizeConstraints.forEach { $0.isActive = false }
        // 以可用宽度为上限计算按钮边长，保证左右留白和间距
        let availableWidth = max(size.width - 40 - spacing, 240) // 40 = 左右 20 留白
        let dimension = max(130, min(160, availableWidth / 2))
        buttonSizeConstraints = [
            takePhotoButton.widthAnchor.constraint(equalToConstant: dimension),
            takePhotoButton.heightAnchor.constraint(equalToConstant: dimension),
            selectPhotoButton.widthAnchor.constraint(equalToConstant: dimension),
            selectPhotoButton.heightAnchor.constraint(equalToConstant: dimension),
        ]
        NSLayoutConstraint.activate(buttonSizeConstraints)

        usageTopConstraint?.constant = isVeryNarrow ? 16 : 20
        view.layoutIfNeeded()
    }

    @objc private func buttonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.12, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
            sender.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
            sender.layer.shadowRadius = 6
            sender.layer.shadowOffset = CGSize(width: 0, height: 4)
            sender.layer.shadowOpacity = 0.2
        }
    }

    @objc private func buttonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.18, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
            sender.transform = .identity
            sender.layer.shadowRadius = 10
            sender.layer.shadowOffset = CGSize(width: 0, height: 8)
            sender.layer.shadowOpacity = 0.25
        }
    }
}

// MARK: - UIImagePickerControllerDelegate
extension MainViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        // 在 dismiss 完成回调中执行 push，避免导航环境树不平衡错误
        picker.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            if let image = info[.originalImage] as? UIImage {
                let resultVC = ResultViewController(originalImage: image, initialQuad: nil)
                self.navigationController?.pushViewController(resultVC, animated: true)
            }
        }
    }
}
