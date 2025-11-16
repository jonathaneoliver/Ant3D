import SceneKit
import UIKit
import os.log

// Create logger for GameViewController3D
private let logger = Logger(subsystem: "com.example.AntAttack3D", category: "GameViewController")

class GameViewController3D: UIViewController {
    
    var sceneView: SCNView!
    public var gameScene: GameScene3D!
    
    // Managers
    var inputManager: InputManager!
    var hudManager: HUDManager!
    
    deinit {
        inputManager?.cleanup()
        hudManager?.cleanup()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // File log
        FileLogger.shared.log("🎮 GameViewController.viewDidLoad() called")
        
        // Triple-log to ensure visibility
        NSLog("🎮 GameViewController viewDidLoad started")
        os_log("🎮 GameViewController viewDidLoad started", type: .error)
        
        FileLogger.shared.log("✅ Creating SceneView")
        
        // Create SceneView with Auto Layout to ensure edge-to-edge positioning
        sceneView = SCNView()
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sceneView)
        
        // Pin SceneView to ALL edges of the view (not safe area)
        NSLayoutConstraint.activate([
            sceneView.topAnchor.constraint(equalTo: view.topAnchor),
            sceneView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sceneView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sceneView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        NSLog("✅ SceneView created and added to view")
        FileLogger.shared.log("✅ SceneView created")
        
        // Create the game scene
        gameScene = GameScene3D()
        sceneView.scene = gameScene
        gameScene.sceneView = sceneView  // Give scene a reference to view for hit testing
        
        NSLog("✅ GameScene created and set")
        FileLogger.shared.log("✅ GameScene created")
        
        // Configure the view
        sceneView.backgroundColor = UIColor(red: 0.59, green: 0.85, blue: 0.93, alpha: 1.0)
        sceneView.allowsCameraControl = false  // Disable built-in camera control so we can control zoom manually
        sceneView.showsStatistics = false     // Will be set by config (default: false)
        sceneView.autoenablesDefaultLighting = false  // We have our own lighting
        
        // Optional: Add antialiasing for smoother edges
        sceneView.antialiasingMode = .multisampling4X
        
        // Setup HUD manager AFTER sceneView is created (so HUD elements appear on top)
        hudManager = HUDManager()
        hudManager.view = view
        hudManager.gameScene = gameScene
        hudManager.setup()
        
        // Start configuration server polling
        ConfigManager.shared.startPolling()
        
        // Setup callbacks
        ConfigManager.shared.onConnectionStatusChanged = { [weak self] isConnected, serverURL in
            self?.hudManager.updateConnectionStatus(isConnected, serverURL: serverURL)
        }
        
        ConfigManager.shared.onConfigUpdate = { [weak self] config in
            self?.hudManager.updateDebugHUDVisibility(config.showDebugHUD)
            self?.sceneView.showsStatistics = config.showsStatistics
            self?.gameScene.onConfigReceived(config)
        }
        
        gameScene.onBallVisibilityChanged = { [weak self] isVisible in
            self?.hudManager.updateBallVisibility(isVisible)
        }
        
        gameScene.onDistanceChanged = { [weak self] distance in
            self?.hudManager.updateDistance(distance)
        }
        
        gameScene.onHostageCountChanged = { [weak self] saved, total in
            self?.hudManager.updateHostageCount(saved, total)
        }
        
        gameScene.onScoreChanged = { [weak self] score in
            self?.hudManager.updateScore(score)
        }
        
        gameScene.onLevelComplete = { [weak self] newLevel in
            self?.hudManager.updateLevel(newLevel)
            self?.hudManager.showLevelCompleteMessage()
        }
        
        gameScene.onGameOver = { [weak self] in
            self?.hudManager.showGameOver()
        }
        
        // HUD manager restart callback
        hudManager.onRestartGame = { [weak self] in
            self?.restartGame()
        }
        
        // Setup input manager (controller, motion, on-screen buttons)
        inputManager = InputManager()
        inputManager.gameScene = gameScene
        inputManager.viewController = self
        inputManager.onCameraRotate = { [weak self] in
            // Visual feedback for rotate button (if visible)
            self?.inputManager.rotateButton?.alpha = 0.5
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.inputManager.rotateButton?.alpha = 1.0
            }
        }
        inputManager.onReturnToTitle = { [weak self] in
            DispatchQueue.main.async {
                self?.navigationController?.popViewController(animated: true)
            }
        }
        inputManager.setup()
        
        // Start camera update loop
        startCameraUpdateLoop()
        
        logger.info("GameViewController loaded")
        NSLog("✅ GameViewController viewDidLoad COMPLETE")
        os_log("✅ GameViewController viewDidLoad COMPLETE", type: .error)
        FileLogger.shared.log("✅ GameViewController viewDidLoad COMPLETE")
        FileLogger.shared.log("📁 Check log file at: \(FileLogger.shared.getLogPath())")
    }
    
    // Make view controller first responder to receive keyboard events
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("🎮 GameViewController viewDidAppear - becoming first responder")
        becomeFirstResponder()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        resignFirstResponder()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return false  // Keep home indicator visible for easy iOS backgrounding
    }
    
    // MARK: - Camera Update Loop
    
    func startCameraUpdateLoop() {
        // Use CADisplayLink for smooth 60fps camera updates
        let displayLink = CADisplayLink(target: self, selector: #selector(updateCamera))
        displayLink.add(to: .main, forMode: .common)
    }
    
    @objc func updateCamera() {
        // Update all game systems (camera, physics, AI, etc.)
        gameScene.update(deltaTime: 1.0/60.0)  // Assume 60 FPS
        
        // Update mini-map (every frame to show real-time positions)
        hudManager.updateMiniMap()
    }
    
    // MARK: - Game Over & Restart
    
    @objc func restartGame() {
        logger.info("Game restarted")
        NSLog("🔄🔄🔄 RESTART BUTTON TAPPED! 🔄🔄🔄")
        
        // Reset game over flag in scene
        gameScene.resetGameOver()
        
        // Unpause the game
        sceneView.scene?.isPaused = false
        
        // Reset ball position to starting location
        let mapWidth = Float(gameScene.cityMap.width)
        let mapHeight = Float(gameScene.cityMap.height)
        gameScene.ballNode.position = SCNVector3(x: mapWidth - 5, y: 5, z: mapHeight - 5)
        gameScene.ballNode.physicsBody?.velocity = SCNVector3(0, 0, 0)
        gameScene.ballNode.physicsBody?.angularVelocity = SCNVector4(0, 0, 0, 0)
        
        // Reset enemy positions
        gameScene.spawnSystem.createEnemyBalls()
    }
}
