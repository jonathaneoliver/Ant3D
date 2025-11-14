import UIKit

/// Main navigation controller to handle transitions between title, game, leaderboard, and about screens
class MainNavigationController: UINavigationController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("🎬 MainNavigationController: viewDidLoad() called")
        
        // Hide navigation bar
        setNavigationBarHidden(true, animated: false)
        
        // Start with title screen
        showTitleScreen()
    }
    
    func showTitleScreen() {
        print("🎬 MainNavigationController: showTitleScreen() called")
        let titleScene = TitleScene3D()
        print("✅ TitleScene3D created successfully")
        
        titleScene.onStartGame = { [weak self] in
            print("🎮 START GAME button tapped")
            self?.showGameScreen()
        }
        
        titleScene.onShowLeaderboard = { [weak self] in
            print("🏆 HIGH SCORES button tapped")
            self?.showLeaderboard(finalScore: -1) // -1 = view only mode
        }
        
        titleScene.onShowAbout = { [weak self] in
            print("ℹ️ ABOUT button tapped")
            self?.showAboutScreen()
        }
        
        print("🎬 Setting TitleScene3D as root view controller")
        setViewControllers([titleScene], animated: false)
        print("✅ TitleScene3D set as root view controller")
    }
    
    func showGameScreen() {
        print("🎮 MainNavigationController: showGameScreen() called")
        let gameVC = GameViewController3D()
        print("✅ GameViewController3D created")
        
        // Need to load the view first so gameScene is initialized
        print("📱 Loading GameViewController view...")
        _ = gameVC.view
        print("✅ GameViewController view loaded")
        
        // Set up game over callback using optional chaining
        if let gameScene = gameVC.gameScene {
            print("✅ gameScene exists, setting up callback")
            gameScene.onGameOver = { [weak self, weak gameVC] in
                print("💀 Game Over! Getting final score...")
                
                // Pause the scene immediately to prevent further updates
                gameVC?.sceneView?.scene?.isPaused = true
                
                // Get final score before any navigation
                let finalScore = gameVC?.gameScene?.score ?? 0
                print("💀 Final score: \(finalScore)")
                
                // Delay navigation slightly to ensure scene is fully paused
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    // Show leaderboard with score
                    self?.showLeaderboard(finalScore: finalScore)
                }
            }
        } else {
            print("❌ Error: gameScene is nil after viewDidLoad!")
        }
        
        print("🎮 Pushing GameViewController to navigation stack")
        pushViewController(gameVC, animated: true)
        print("✅ GameViewController pushed")
    }
    
    func showLeaderboard(finalScore: Int) {
        print("🏆 MainNavigationController: showLeaderboard(finalScore: \(finalScore)) called")
        let leaderboardScene = LeaderboardScene3D()
        leaderboardScene.setFinalScore(finalScore)
        print("✅ LeaderboardScene3D created with finalScore: \(finalScore)")
        
        leaderboardScene.onBack = { [weak self] in
            print("◀️ BACK button tapped from leaderboard")
            // Return to title screen
            self?.showTitleScreen()
        }
        
        if finalScore >= 0 {
            // New high score mode - push
            print("🏆 Pushing leaderboard (new high score mode)")
            pushViewController(leaderboardScene, animated: true)
        } else {
            // View only mode - push
            print("🏆 Pushing leaderboard (view only mode)")
            pushViewController(leaderboardScene, animated: true)
        }
        print("✅ LeaderboardScene3D pushed")
    }
    
    func showAboutScreen() {
        print("ℹ️ MainNavigationController: showAboutScreen() called")
        let aboutScene = AboutScene3D()
        print("✅ AboutScene3D created")
        
        aboutScene.onBack = { [weak self] in
            print("◀️ BACK button tapped from about")
            self?.popViewController(animated: true)
        }
        
        print("ℹ️ Pushing AboutScene3D to navigation stack")
        pushViewController(aboutScene, animated: true)
        print("✅ AboutScene3D pushed")
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
}
