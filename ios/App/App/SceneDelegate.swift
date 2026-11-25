import UIKit
import Capacitor
import GameKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        window = UIWindow(windowScene: windowScene)
        let bridgeVC = CAPBridgeViewController()
        window?.rootViewController = bridgeVC
        window?.makeKeyAndVisible()

        // Disable zooming on webView scrollView
        DispatchQueue.main.async {
            bridgeVC.webView?.scrollView.maximumZoomScale = 1.0
            bridgeVC.webView?.scrollView.minimumZoomScale = 1.0
            bridgeVC.webView?.scrollView.bouncesZoom = false
        }

        // Tự động đăng nhập Game Center ngay khi mở App
        setupGameCenterAutoLogin(rootVC: bridgeVC)

        SceneDelegateProxy.shared.scene(scene, willConnectTo: session, options: connectionOptions)
    }

    func setupGameCenterAutoLogin(rootVC: UIViewController?) {
        let player = GKLocalPlayer.local
        player.authenticateHandler = { [weak rootVC] viewController, error in
            if let vc = viewController {
                DispatchQueue.main.async {
                    rootVC?.present(vc, animated: true, completion: nil)
                }
            } else if player.isAuthenticated {
                print("[GameCenter] Auto-login SUCCESS as: \(player.alias) (ID: \(player.gamePlayerID))")
                DispatchQueue.main.async {
                    if #available(iOS 14.0, *) {
                        GKAccessPoint.shared.location = .topTrailing
                        GKAccessPoint.shared.showHighlights = true
                        GKAccessPoint.shared.isActive = true
                    }
                }
            } else if let error = error {
                print("[GameCenter] Auto-login notice: \(error.localizedDescription)")
            }
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        SceneDelegateProxy.shared.scene(scene, openURLContexts: URLContexts)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        SceneDelegateProxy.shared.scene(scene, continue: userActivity)
    }
}
