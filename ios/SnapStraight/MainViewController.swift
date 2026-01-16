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

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = .white

        // 顶部标题区域
        appTitleLabel.text = NSLocalizedString("app_name", comment: "")
        appTitleLabel.font = UIFont.systemFont(ofSize: 36, weight: .medium)
        appTitleLabel.textColor = .black
        appTitleLabel.textAlignment = .center
        appTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(appTitleLabel)

        appSubtitleLabel.text = NSLocalizedString("app_name_en", comment: "")
        appSubtitleLabel.font = UIFont.systemFont(ofSize: 28, weight: .regular)
        appSubtitleLabel.textColor = UIColor(white: 0.4, alpha: 1.0)
        appSubtitleLabel.textAlignment = .center
        appSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(appSubtitleLabel)

        // 拍照按钮
        takePhotoButton.setTitle(NSLocalizedString("btn_take_photo", comment: ""), for: .normal)
        takePhotoButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .medium)
        takePhotoButton.setTitleColor(.white, for: .normal)
        takePhotoButton.backgroundColor = UIColor(red: 0.13, green: 0.59, blue: 0.95, alpha: 1.0)  // #2196F3
        takePhotoButton.layer.cornerRadius = 80
        takePhotoButton.addTarget(self, action: #selector(takePhotoTapped), for: .touchUpInside)
        takePhotoButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(takePhotoButton)

        // 选图按钮
        selectPhotoButton.setTitle(NSLocalizedString("btn_select_photo", comment: ""), for: .normal)
        selectPhotoButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .medium)
        selectPhotoButton.setTitleColor(.white, for: .normal)
        selectPhotoButton.backgroundColor = UIColor(red: 0.30, green: 0.69, blue: 0.31, alpha: 1.0)  // #4CAF50
        selectPhotoButton.layer.cornerRadius = 80
        selectPhotoButton.addTarget(self, action: #selector(selectPhotoTapped), for: .touchUpInside)
        selectPhotoButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(selectPhotoButton)

        // 布局约束
        NSLayoutConstraint.activate([
            // 标题
            appTitleLabel.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            appTitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            appSubtitleLabel.topAnchor.constraint(equalTo: appTitleLabel.bottomAnchor, constant: 8),
            appSubtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // 按钮
            takePhotoButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            takePhotoButton.trailingAnchor.constraint(equalTo: view.centerXAnchor, constant: -20),
            takePhotoButton.widthAnchor.constraint(equalToConstant: 160),
            takePhotoButton.heightAnchor.constraint(equalToConstant: 160),

            selectPhotoButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            selectPhotoButton.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: 20),
            selectPhotoButton.widthAnchor.constraint(equalToConstant: 160),
            selectPhotoButton.heightAnchor.constraint(equalToConstant: 160),
        ])
    }

    @objc private func takePhotoTapped() {
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
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UIImagePickerControllerDelegate
extension MainViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)

        if let image = info[.originalImage] as? UIImage {
            // 进入交互结果页（原图 + 用户可调整四边形）
            let resultVC = ResultViewController(originalImage: image, initialQuad: nil)
            self.navigationController?.pushViewController(resultVC, animated: true)
        }
    }
}
