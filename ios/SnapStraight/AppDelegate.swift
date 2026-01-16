import UIKit

/**
 * App入口
 */
@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, 
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // 设置主窗口
        window = UIWindow(frame: UIScreen.main.bounds)
        let mainVC = MainViewController()
        let navController = UINavigationController(rootViewController: mainVC)
        navController.isNavigationBarHidden = true
        window?.rootViewController = navController
        window?.makeKeyAndVisible()
        
        return true
    }
}
