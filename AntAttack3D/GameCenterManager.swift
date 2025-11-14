import GameKit
import UIKit

class GameCenterManager: NSObject {
    static let shared = GameCenterManager()
    
    var isAuthenticated = false
    var localPlayer: GKLocalPlayer?
    
    // Leaderboard ID - update this in App Store Connect
    private let leaderboardID = "antattack3d_highscores"
    
    override init() {
        super.init()
        authenticateLocalPlayer()
    }
    
    func authenticateLocalPlayer() {
        localPlayer = GKLocalPlayer.local
        
        print("🎮 [GameCenter] Starting authentication...")
        
        localPlayer?.authenticateHandler = { [weak self] viewController, error in
            if let viewController = viewController {
                print("🎮 [GameCenter] Presenting authentication view controller")
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController?.present(viewController, animated: true)
                }
            } else if let error = error {
                print("❌ [GameCenter] Authentication error: \(error.localizedDescription)")
                self?.isAuthenticated = false
            } else {
                self?.isAuthenticated = self?.localPlayer?.isAuthenticated ?? false
                if let player = self?.localPlayer {
                    print("✅ [GameCenter] Authenticated: \(player.isAuthenticated)")
                    print("✅ [GameCenter] Player: \(player.displayName)")
                    print("✅ [GameCenter] PlayerID: \(player.gamePlayerID)")
                } else {
                    print("❌ [GameCenter] No local player found")
                }
            }
        }
    }
    
    func submitScore(_ score: Int) {
        guard isAuthenticated else {
            print("❌ [GameCenter] Player not authenticated - cannot submit score")
            return
        }
        
        print("📤 [GameCenter] Submitting score: \(score) to leaderboard: \(leaderboardID)")
        
        let scoreObject = GKScore(leaderboardIdentifier: leaderboardID)
        scoreObject.value = Int64(score)
        
        GKScore.report([scoreObject]) { error in
            if let error = error {
                let nsError = error as NSError
                if nsError.domain == "GKErrorDomain" && nsError.code == 17 {
                    print("⚠️ [GameCenter] Leaderboard not yet created in App Store Connect")
                } else {
                    print("❌ [GameCenter] Error submitting score: \(error.localizedDescription)")
                }
            } else {
                print("✅ [GameCenter] Score submitted successfully: \(score)")
            }
        }
    }
    
    func loadLeaderboard(completion: @escaping ([GKScore]?) -> Void) {
        guard isAuthenticated else {
            print("❌ [GameCenter] Cannot load leaderboard - not authenticated")
            completion(nil)
            return
        }
        
        print("📥 [GameCenter] Loading leaderboard: \(leaderboardID)")
        
        let leaderboard = GKLeaderboard()
        leaderboard.identifier = leaderboardID
        leaderboard.playerScope = .global
        leaderboard.range = NSMakeRange(1, 100)
        
        leaderboard.loadScores { [weak self] scores, error in
            if let error = error {
                let nsError = error as NSError
                if nsError.domain == "GKServerErrorDomain" && nsError.code == 5053 {
                    print("⚠️ [GameCenter] Leaderboard '\(self?.leaderboardID ?? "unknown")' not yet created in App Store Connect")
                } else {
                    print("❌ [GameCenter] Error loading leaderboard: \(error.localizedDescription)")
                }
                completion(nil)
            } else {
                if let scores = scores {
                    print("✅ [GameCenter] Loaded \(scores.count) scores from leaderboard")
                    if scores.isEmpty {
                        print("⚠️ [GameCenter] Leaderboard is empty - no scores yet")
                    } else {
                        print("📊 [GameCenter] Top score: \(scores.first?.value ?? 0)")
                    }
                } else {
                    print("⚠️ [GameCenter] No scores returned (nil)")
                }
                completion(scores)
            }
        }
    }
    
    func showGameCenterLeaderboard() {
        guard isAuthenticated else {
            print("❌ [GameCenter] Player not authenticated")
            return
        }
        
        let leaderboardViewController = GKGameCenterViewController(leaderboardID: leaderboardID, playerScope: .global, timeScope: .allTime)
        leaderboardViewController.gameCenterDelegate = self
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(leaderboardViewController, animated: true)
        }
    }
}

extension GameCenterManager: GKGameCenterControllerDelegate {
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
