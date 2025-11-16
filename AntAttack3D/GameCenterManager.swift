import GameKit
import UIKit


// Game Center error types for better error handling
enum GameCenterError: LocalizedError {
    case notAuthenticated
    case leaderboardNotFound(String)
    case submitFailed(Error)
    case loadFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Player is not authenticated with Game Center"
        case .leaderboardNotFound(let id):
            return "Leaderboard '\(id)' not found in App Store Connect"
        case .submitFailed(let error):
            return "Failed to submit score: \(error.localizedDescription)"
        case .loadFailed(let error):
            return "Failed to load leaderboard: \(error.localizedDescription)"
        }
    }
}


class GameCenterManager: NSObject {
    static let shared = GameCenterManager()
    
    var isAuthenticated = false {
        didSet {
            // Post notification when authentication state changes
            NotificationCenter.default.post(
                name: NSNotification.Name("GameCenterAuthenticationChanged"),
                object: nil
            )
        }
    }
    var localPlayer: GKLocalPlayer?
    var authenticationError: Error?
    
    // Leaderboard ID - update this in App Store Connect
    private let leaderboardID = "antattack3d_highscores"
    
    override init() {
        super.init()
        authenticateLocalPlayer()
    }
    
    func authenticateLocalPlayer() {
        localPlayer = GKLocalPlayer.local
        
        print("🎮 [GameCenter] Starting authentication...")
        
        #if targetEnvironment(simulator)
        print("⚠️ [GameCenter] Running in Simulator - Game Center may not work properly")
        #endif
        
        localPlayer?.authenticateHandler = { [weak self] viewController, error in
            if let viewController = viewController {
                print("🎮 [GameCenter] Presenting authentication view controller")
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController?.present(viewController, animated: true)
                }
            } else if let error = error {
                let nsError = error as NSError
                print("❌ [GameCenter] Authentication error: \(error.localizedDescription)")
                print("❌ [GameCenter] Error domain: \(nsError.domain), code: \(nsError.code)")
                
                // Handle specific error cases
                switch (nsError.domain, nsError.code) {
                case ("GKErrorDomain", 3):
                    // Server communication error - common in simulator
                    #if targetEnvironment(simulator)
                    print("⚠️ [GameCenter] Simulator limitation - Game Center requires a real device")
                    #else
                    print("⚠️ [GameCenter] Server communication error - check network connection")
                    #endif
                    
                case ("GKErrorDomain", 2):
                    // User cancelled authentication
                    print("⚠️ [GameCenter] User cancelled authentication")
                    
                case ("GKErrorDomain", 4):
                    // Authentication failed
                    print("⚠️ [GameCenter] Authentication failed - user may not be signed in")
                    
                default:
                    print("⚠️ [GameCenter] Unknown error: \(nsError)")
                }
                
                self?.authenticationError = error
                self?.isAuthenticated = false
            } else {
                self?.isAuthenticated = self?.localPlayer?.isAuthenticated ?? false
                self?.authenticationError = nil
                
                if let player = self?.localPlayer {
                    if player.isAuthenticated {
                        print("✅ [GameCenter] Authenticated: \(player.isAuthenticated)")
                        print("✅ [GameCenter] Player: \(player.displayName)")
                        print("✅ [GameCenter] PlayerID: \(player.gamePlayerID)")
                    } else {
                        print("⚠️ [GameCenter] Player not authenticated")
                        #if targetEnvironment(simulator)
                        print("⚠️ [GameCenter] Note: Game Center is not supported in the Simulator")
                        print("⚠️ [GameCenter] Please test on a real device with an Apple ID signed into Game Center")
                        #endif
                    }
                } else {
                    print("❌ [GameCenter] No local player found")
                }
            }
        }
    }
    
    func submitScore(_ score: Int) {
        guard isAuthenticated else {
            print("❌ [GameCenter] Player not authenticated - cannot submit score")
            #if targetEnvironment(simulator)
            print("⚠️ [GameCenter] Game Center requires a real device - score saved locally only")
            #endif
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
    
    func getStatusMessage() -> String {
        if isAuthenticated {
            return "Connected"
        } else if let error = authenticationError as? NSError {
            #if targetEnvironment(simulator)
            return "Simulator Only"
            #else
            switch (error.domain, error.code) {
            case ("GKErrorDomain", 3):
                return "Network Error"
            case ("GKErrorDomain", 2):
                return "Not Signed In"
            case ("GKErrorDomain", 4):
                return "Auth Failed"
            default:
                return "Offline"
            }
            #endif
        } else {
            return "Connecting..."
        }
    }
}

extension GameCenterManager: GKGameCenterControllerDelegate {
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
