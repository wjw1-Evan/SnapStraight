import UIKit
import Photos

/**
 * 结果展示ViewController
 * 显示处理后的图片，提供保存功能
 */
class ResultViewController: UIViewController {
    
    private let resultImage: UIImage
    private let imageView = UIImageView()
    private let backButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    
    init(image: UIImage) {
        self.resultImage = image
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
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
        imageView.image = resultImage
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        
        // 保存按钮
        saveButton.setTitle(NSLocalizedString("btn_save", comment: ""), for: .normal)
        saveButton.titleLabel?.font = UIFont.systemFont(ofSize: 28, weight: .medium)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.backgroundColor = UIColor(red: 0.96, green: 0.26, blue: 0.21, alpha: 1.0) // #F44336
        saveButton.layer.cornerRadius = 16
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(saveButton)
        
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            imageView.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -32),
            
            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            saveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            saveButton.heightAnchor.constraint(equalToConstant: 80)
        ])
    }
    
    @objc private func backTapped() {
        navigationController?.popToRootViewController(animated: true)
    }
    
    @objc private func saveTapped() {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: self.resultImage)
        }) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.showSaveSuccess()
                } else {
                    self?.showSaveError()
                }
            }
        }
    }
    
    private func showSaveSuccess() {
        // 轻微震动
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // 显示提示
        let alert = UIAlertController(
            title: nil,
            message: NSLocalizedString("save_success", comment: ""),
            preferredStyle: .alert
        )
        present(alert, animated: true)
        
        // 自动返回主页
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
