import Foundation
import Capacitor
import GameKit

@objc(GameCenterPlugin)
public class GameCenterPlugin: CAPPlugin, CAPBridgedPlugin, GKGameCenterControllerDelegate {
    public let identifier = "GameCenterPlugin"
    public let jsName = "GameCenter"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "authenticate", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "showLeaderboard", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "submitScore", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getPlayerProfile", returnType: CAPPluginReturnPromise)
    ]
    
    @objc func authenticate(_ call: CAPPluginCall) {
        let player = GKLocalPlayer.local
        
        // 1. Nếu người chơi đã đăng nhập từ trước, trả về ngay lập tức
        if player.isAuthenticated {
            DispatchQueue.main.async {
                if #available(iOS 14.0, *) {
                    GKAccessPoint.shared.isActive = false
                }
            }
            print("[GameCenter] Already authenticated: \(player.alias) (ID: \(player.gamePlayerID))")
            call.resolve([
                "authenticated": true,
                "playerID": player.gamePlayerID,
                "alias": player.alias,
                "displayName": player.displayName
            ])
            return
        }
        
        // 2. Thiết lập authenticateHandler để iOS hiển thị giao diện đăng nhập Game Center nếu cần
        player.authenticateHandler = { [weak self] vc, error in
            guard let self = self else { return }
            
            if let vc = vc {
                DispatchQueue.main.async {
                    let presenter = self.topViewController() ?? self.bridge?.viewController
                    presenter?.present(vc, animated: true, completion: nil)
                }
            } else if player.isAuthenticated {
                DispatchQueue.main.async {
                    if #available(iOS 14.0, *) {
                        GKAccessPoint.shared.isActive = false
                    }
                }
                print("[GameCenter] Login SUCCESS: \(player.alias) (ID: \(player.gamePlayerID))")
                call.resolve([
                    "authenticated": true,
                    "playerID": player.gamePlayerID,
                    "alias": player.alias,
                    "displayName": player.displayName
                ])
            } else {
                let errMsg = error?.localizedDescription ?? "Game Center login required in iOS Settings"
                print("[GameCenter] Login notice: \(errMsg)")
                call.resolve([
                    "authenticated": false,
                    "error": errMsg,
                    "alias": "Stickman Fighter",
                    "displayName": "Stickman Fighter"
                ])
            }
        }
    }
    
    private func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let base = base ?? self.bridge?.viewController ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.rootViewController
        
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
    
    @objc func showLeaderboard(_ call: CAPPluginCall) {
        let leaderboardID = call.getString("leaderboardID")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if #available(iOS 14.0, *) {
                let gcViewController: GKGameCenterViewController
                if let leaderboardID = leaderboardID, !leaderboardID.isEmpty {
                    gcViewController = GKGameCenterViewController(leaderboardID: leaderboardID, playerScope: .global, timeScope: .allTime)
                } else {
                    gcViewController = GKGameCenterViewController(state: .leaderboards)
                }
                gcViewController.gameCenterDelegate = self
                self.bridge?.viewController?.present(gcViewController, animated: true) {
                    call.resolve(["success": true])
                }
            } else {
                let gcViewController = GKGameCenterViewController()
                gcViewController.gameCenterDelegate = self
                if let leaderboardID = leaderboardID, !leaderboardID.isEmpty {
                    gcViewController.leaderboardIdentifier = leaderboardID
                }
                gcViewController.viewState = .leaderboards
                self.bridge?.viewController?.present(gcViewController, animated: true) {
                    call.resolve(["success": true])
                }
            }
        }
    }
    
    @objc func submitScore(_ call: CAPPluginCall) {
        let score = call.getInt("score") ?? 0
        let leaderboardID = call.getString("leaderboardID") ?? "stickman_war_leaderboard"
        
        guard GKLocalPlayer.local.isAuthenticated else {
            call.resolve(["submitted": false, "reason": "Not authenticated"])
            return
        }
        
        if #available(iOS 14.0, *) {
            GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [leaderboardID]) { error in
                if let error = error {
                    call.reject("Error submitting score: \(error.localizedDescription)")
                } else {
                    call.resolve(["submitted": true, "score": score])
                }
            }
        } else {
            let scoreReporter = GKScore(leaderboardIdentifier: leaderboardID)
            scoreReporter.value = Int64(score)
            GKScore.report([scoreReporter]) { error in
                if let error = error {
                    call.reject("Error submitting score: \(error.localizedDescription)")
                } else {
                    call.resolve(["submitted": true, "score": score])
                }
            }
        }
    }
    
    @objc func getPlayerProfile(_ call: CAPPluginCall) {
        let player = GKLocalPlayer.local
        call.resolve([
            "authenticated": player.isAuthenticated,
            "playerID": player.isAuthenticated ? player.gamePlayerID : "",
            "alias": player.isAuthenticated ? player.alias : "Player",
            "displayName": player.isAuthenticated ? player.displayName : "Stickman Fighter"
        ])
    }
    
    public func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true, completion: nil)
    }
}
