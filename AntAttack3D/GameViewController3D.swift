import SceneKit
import UIKit
import GameController
import os.log

// Create logger for GameViewController3D
private let logger = Logger(subsystem: "com.example.AntAttack3D", category: "GameViewController")

class GameViewController3D: UIViewController {
    
    var sceneView: SCNView!
    public var gameScene: GameScene3D!
    var connectionStatusLabel: UILabel!
    var debugLabel: UILabel!  // Big visible debug label
    var visibilityLabel: UILabel!  // Ball visibility indicator
    var distanceLabel: UILabel!  // Camera distance from ball
    var hostageLabel: UILabel!  // Hostage rescue counter
    var scoreLabel: UILabel!  // Score display
    var levelLabel: UILabel!  // Current level display
    var miniMapView: UIView!  // Mini-map showing hostage locations
    var miniMapDots: [UIView] = []  // Blue dots for hostages
    var miniMapPlayerDot: UIView?  // Red dot for player position
    var axisView: SCNView!  // 3D axis indicator
    var controller: GCController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // File log
        FileLogger.shared.log("🎮 GameViewController.viewDidLoad() called")
        
        // Triple-log to ensure visibility
        NSLog("🎮 GameViewController viewDidLoad started")
        os_log("🎮 GameViewController viewDidLoad started", type: .error)
        
        // FIRST: Create a big visible debug label
        setupBigDebugLabel()
        updateDebugLabel("viewDidLoad started")
        
        FileLogger.shared.log("✅ Creating SceneView")
        
        // Create and configure the SceneKit view
        sceneView = SCNView(frame: view.bounds)
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(sceneView)
        
        NSLog("✅ SceneView created and added to view")
        FileLogger.shared.log("✅ SceneView created")
        updateDebugLabel("SceneView created")
        
        // Create the game scene
        gameScene = GameScene3D()
        sceneView.scene = gameScene
        gameScene.sceneView = sceneView  // Give scene a reference to view for hit testing
        
        NSLog("✅ GameScene created and set")
        FileLogger.shared.log("✅ GameScene created")
        updateDebugLabel("GameScene created")
        
        // Configure the view
        sceneView.backgroundColor = UIColor(red: 0.59, green: 0.85, blue: 0.93, alpha: 1.0)
        sceneView.allowsCameraControl = false  // Disable built-in camera control so we can control zoom manually
        sceneView.showsStatistics = true      // Show FPS and other stats
        sceneView.autoenablesDefaultLighting = false  // We have our own lighting
        
        // Optional: Add antialiasing for smoother edges
        sceneView.antialiasingMode = .multisampling4X
        
        // Setup connection status HUD
        setupConnectionStatusHUD()
        setupVisibilityHUD()
        setupDistanceHUD()
        setupScoreHUD()
        setupLevelHUD()
        setupHostageHUD()
        setupMiniMap()
        
        // Set initial visibility to hidden (default state)
        updateDebugHUDVisibility(false)
        
        updateDebugLabel("HUD setup complete")
        
        // Start configuration server polling
        ConfigManager.shared.startPolling()
        updateDebugLabel("Config polling started")
        
        // Setup connection status listener
        ConfigManager.shared.onConnectionStatusChanged = { [weak self] isConnected, serverURL in
            self?.updateConnectionStatus(isConnected, serverURL: serverURL)
        }
        
        // Setup ball visibility listener
        gameScene.onBallVisibilityChanged = { [weak self] isVisible in
            self?.updateBallVisibility(isVisible)
        }
        
        // Setup distance listener
        gameScene.onDistanceChanged = { [weak self] distance in
            self?.updateDistance(distance)
        }
        
        // Setup hostage count listener
        gameScene.onHostageCountChanged = { [weak self] saved, total in
            self?.updateHostageCount(saved, total)
        }
        
        // Setup score listener
        gameScene.onScoreChanged = { [weak self] score in
            self?.updateScore(score)
        }
        
        // Setup level complete listener
        gameScene.onLevelComplete = { [weak self] newLevel in
            self?.updateLevel(newLevel)
            // Show "Level Complete!" message
            self?.showLevelCompleteMessage()
        }
        
        // Setup config update listener for debug HUD visibility AND forward to game scene
        ConfigManager.shared.onConfigUpdate = { [weak self] config in
            self?.updateDebugHUDVisibility(config.showDebugHUD)
            // Forward config update to game scene for camera/lighting updates
            self?.gameScene.onConfigReceived(config)
        }
        
        // Setup game over callback
        setupGameOverCallback()
        
        // Setup Xbox controller
        setupGameController()
        updateDebugLabel("Controller setup complete")
        
        // Start camera update loop
        startCameraUpdateLoop()
        
        logger.info("GameViewController loaded")
        NSLog("✅ GameViewController viewDidLoad COMPLETE")
        os_log("✅ GameViewController viewDidLoad COMPLETE", type: .error)
        FileLogger.shared.log("✅ GameViewController viewDidLoad COMPLETE")
        FileLogger.shared.log("📁 Check log file at: \(FileLogger.shared.getLogPath())")
        updateDebugLabel("✅ READY - Log: \(FileLogger.shared.getLogPath())")
    }
    
    // MARK: - Big Debug Label (visible on screen)
    
    func setupBigDebugLabel() {
        debugLabel = UILabel()
        debugLabel.translatesAutoresizingMaskIntoConstraints = false
        debugLabel.font = UIFont.boldSystemFont(ofSize: 18)
        debugLabel.textColor = .yellow
        debugLabel.backgroundColor = UIColor.red.withAlphaComponent(0.8)
        debugLabel.textAlignment = .center
        debugLabel.numberOfLines = 0
        debugLabel.text = "STARTING APP..."
        
        view.addSubview(debugLabel)
        
        NSLayoutConstraint.activate([
            debugLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            debugLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            debugLabel.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8)
        ])
        
        FileLogger.shared.log("✅ Big debug label created and visible")
    }
    
    func updateDebugLabel(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.debugLabel.text = message
            FileLogger.shared.log("📺 Debug label: \(message)")
        }
    }
    

    
    // MARK: - Connection Status HUD
    
    func setupConnectionStatusHUD() {
        
        // Create status label
        connectionStatusLabel = UILabel()
        connectionStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        connectionStatusLabel.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        connectionStatusLabel.textColor = .yellow
        connectionStatusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        connectionStatusLabel.textAlignment = .center
        connectionStatusLabel.numberOfLines = 1
        connectionStatusLabel.text = " ⏳ Connecting to config server... "
        connectionStatusLabel.layer.cornerRadius = 4
        connectionStatusLabel.layer.masksToBounds = true
        connectionStatusLabel.adjustsFontSizeToFitWidth = true
        connectionStatusLabel.minimumScaleFactor = 0.7
        
        // Rotate 90 degrees counter-clockwise so text reads vertically along left edge
        connectionStatusLabel.transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 2)
        
        view.addSubview(connectionStatusLabel)
        
        // Position on far left edge, just below the time display (top area)
        // Note: After rotation, width becomes height and vice versa in layout
        NSLayoutConstraint.activate([
            connectionStatusLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 120), // Below time (12:29), using topAnchor without safeArea
            connectionStatusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8), // Use view.leadingAnchor to get far left
            connectionStatusLabel.widthAnchor.constraint(equalToConstant: 200), // Visual height after rotation
            connectionStatusLabel.heightAnchor.constraint(equalToConstant: 24)   // Visual width after rotation
        ])
        
    }
    
    func updateConnectionStatus(_ isConnected: Bool, serverURL: String) {
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if isConnected {
                self.connectionStatusLabel.text = " ● \(serverURL) "
                self.connectionStatusLabel.textColor = UIColor(red: 0.3, green: 1.0, blue: 0.3, alpha: 1.0) // Bright green
                self.connectionStatusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            } else {
                self.connectionStatusLabel.text = " ○ \(serverURL) "
                self.connectionStatusLabel.textColor = UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0) // Bright red
                self.connectionStatusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            }
        }
    }
    
    // MARK: - Ball Visibility HUD
    
    func setupVisibilityHUD() {
        
        // Create visibility label
        visibilityLabel = UILabel()
        visibilityLabel.translatesAutoresizingMaskIntoConstraints = false
        visibilityLabel.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .bold)
        visibilityLabel.textColor = .yellow
        visibilityLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        visibilityLabel.textAlignment = .center
        visibilityLabel.numberOfLines = 1
        visibilityLabel.text = " 🎯 Ball: ??? "
        visibilityLabel.layer.cornerRadius = 4
        visibilityLabel.layer.masksToBounds = true
        visibilityLabel.adjustsFontSizeToFitWidth = true
        visibilityLabel.minimumScaleFactor = 0.7
        
        // Rotate 90 degrees counter-clockwise so text reads vertically
        visibilityLabel.transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 2)
        
        view.addSubview(visibilityLabel)
        
        // Position on far left edge, below connection status
        NSLayoutConstraint.activate([
            visibilityLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 330), // Below connection status
            visibilityLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8), // Far left
            visibilityLabel.widthAnchor.constraint(equalToConstant: 140), // Visual height after rotation
            visibilityLabel.heightAnchor.constraint(equalToConstant: 28)   // Visual width after rotation
        ])
        
    }
    
    func updateBallVisibility(_ isVisible: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if isVisible {
                self.visibilityLabel.text = " 🎯 Ball: VISIBLE "
                self.visibilityLabel.textColor = UIColor(red: 0.3, green: 1.0, blue: 0.3, alpha: 1.0) // Bright green
                self.visibilityLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            } else {
                self.visibilityLabel.text = " ⚠️ Ball: HIDDEN "
                self.visibilityLabel.textColor = UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0) // Bright red
                self.visibilityLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            }
        }
    }
    
    // MARK: - Distance HUD
    
    func setupDistanceHUD() {
        
        // Create distance label
        distanceLabel = UILabel()
        distanceLabel.translatesAutoresizingMaskIntoConstraints = false
        distanceLabel.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .bold)
        distanceLabel.textColor = .cyan
        distanceLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        distanceLabel.textAlignment = .center
        distanceLabel.numberOfLines = 1
        distanceLabel.text = " 📏 Dist: ??? "
        distanceLabel.layer.cornerRadius = 4
        distanceLabel.layer.masksToBounds = true
        distanceLabel.adjustsFontSizeToFitWidth = true
        distanceLabel.minimumScaleFactor = 0.7
        
        // Rotate 90 degrees counter-clockwise so text reads vertically
        distanceLabel.transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 2)
        
        view.addSubview(distanceLabel)
        
        // Position on far left edge, below visibility label
        NSLayoutConstraint.activate([
            distanceLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 480), // Below visibility label
            distanceLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8), // Far left
            distanceLabel.widthAnchor.constraint(equalToConstant: 120), // Visual height after rotation
            distanceLabel.heightAnchor.constraint(equalToConstant: 28)   // Visual width after rotation
        ])
        
    }
    
    func updateDistance(_ distance: Float) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update label with current distance
            self.distanceLabel.text = String(format: " 📏 Dist: %.1f ", distance)
            self.distanceLabel.textColor = .cyan
            self.distanceLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        }
    }
    
    // MARK: - Hostage Rescue HUD
    
    func setupHostageHUD() {
        
        // Create hostage label
        hostageLabel = UILabel()
        hostageLabel.translatesAutoresizingMaskIntoConstraints = false
        hostageLabel.font = UIFont.monospacedSystemFont(ofSize: 16, weight: .bold)
        hostageLabel.textColor = .cyan
        hostageLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        hostageLabel.textAlignment = .center
        hostageLabel.numberOfLines = 1
        hostageLabel.text = " 💙 Remaining: 0/0 "
        hostageLabel.layer.cornerRadius = 6
        hostageLabel.layer.masksToBounds = true
        hostageLabel.adjustsFontSizeToFitWidth = true
        hostageLabel.minimumScaleFactor = 0.7
        
        view.addSubview(hostageLabel)
        
        // Position at top-center, to the left of level label (matches HUD style)
        NSLayoutConstraint.activate([
            hostageLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            hostageLabel.trailingAnchor.constraint(equalTo: levelLabel.leadingAnchor, constant: -10),
            hostageLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
            hostageLabel.heightAnchor.constraint(equalToConstant: 32)
        ])
        
    }
    
    func updateHostageCount(_ saved: Int, _ total: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let remaining = total - saved
            
            // Update label to show remaining hostages
            self.hostageLabel.text = String(format: " 💙 Remaining: %d/%d ", remaining, total)
            
            // Change color based on status
            if saved == total && total > 0 {
                self.hostageLabel.textColor = .green  // All saved!
                self.hostageLabel.backgroundColor = UIColor.black.withAlphaComponent(0.8)
            } else if saved > 0 {
                self.hostageLabel.textColor = .cyan  // Some saved
                self.hostageLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            } else {
                self.hostageLabel.textColor = .yellow  // None saved yet
                self.hostageLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            }
        }
    }
    
    // MARK: - Score HUD
    
    func setupScoreHUD() {
        
        // Create score label
        scoreLabel = UILabel()
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false
        scoreLabel.font = UIFont.monospacedSystemFont(ofSize: 16, weight: .bold)
        scoreLabel.textColor = .yellow
        scoreLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        scoreLabel.textAlignment = .center
        scoreLabel.numberOfLines = 1
        scoreLabel.text = " 🏆 Score: 0 "
        scoreLabel.layer.cornerRadius = 6
        scoreLabel.layer.masksToBounds = true
        scoreLabel.adjustsFontSizeToFitWidth = true
        scoreLabel.minimumScaleFactor = 0.7
        
        view.addSubview(scoreLabel)
        
        // Position at top-center of screen (horizontal, no rotation)
        NSLayoutConstraint.activate([
            scoreLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            scoreLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scoreLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
            scoreLabel.heightAnchor.constraint(equalToConstant: 32)
        ])
        
    }
    
    func updateScore(_ score: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update label with current score
            self.scoreLabel.text = String(format: " 🏆 Score: %d ", score)
            self.scoreLabel.textColor = .yellow
            self.scoreLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        }
    }
    
    // MARK: - Level HUD
    
    func setupLevelHUD() {
        
        // Create level label (to the left of score label)
        levelLabel = UILabel()
        levelLabel.translatesAutoresizingMaskIntoConstraints = false
        levelLabel.font = UIFont.monospacedSystemFont(ofSize: 16, weight: .bold)
        levelLabel.textColor = .cyan
        levelLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        levelLabel.textAlignment = .center
        levelLabel.numberOfLines = 1
        levelLabel.text = " 🎮 Level: 1 "
        levelLabel.layer.cornerRadius = 6
        levelLabel.layer.masksToBounds = true
        levelLabel.adjustsFontSizeToFitWidth = true
        levelLabel.minimumScaleFactor = 0.7
        
        view.addSubview(levelLabel)
        
        // Position at top-center, to the left of score label
        NSLayoutConstraint.activate([
            levelLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            levelLabel.trailingAnchor.constraint(equalTo: scoreLabel.leadingAnchor, constant: -10),
            levelLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            levelLabel.heightAnchor.constraint(equalToConstant: 32)
        ])
        
    }
    
    func updateLevel(_ level: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update label with current level
            self.levelLabel.text = String(format: " 🎮 Level: %d ", level)
            self.levelLabel.textColor = .cyan
            self.levelLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        }
    }
    
    // MARK: - Mini-Map HUD
    
    func setupMiniMap() {
        // Create mini-map container view (bottom-right corner)
        miniMapView = UIView()
        miniMapView.translatesAutoresizingMaskIntoConstraints = false
        miniMapView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        miniMapView.layer.cornerRadius = 8
        miniMapView.layer.masksToBounds = true
        miniMapView.layer.borderWidth = 2
        miniMapView.layer.borderColor = UIColor.cyan.cgColor
        miniMapView.isUserInteractionEnabled = false  // Don't block controller input!
        
        view.addSubview(miniMapView)
        
        // Position at bottom-right corner
        let mapSize: CGFloat = 120
        NSLayoutConstraint.activate([
            miniMapView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            miniMapView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            miniMapView.widthAnchor.constraint(equalToConstant: mapSize),
            miniMapView.heightAnchor.constraint(equalToConstant: mapSize)
        ])
        
        // Add title label
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "MAP"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 10)
        titleLabel.textColor = .cyan
        titleLabel.textAlignment = .center
        miniMapView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: miniMapView.topAnchor, constant: 2),
            titleLabel.centerXAnchor.constraint(equalTo: miniMapView.centerXAnchor)
        ])
    }
    
    func updateMiniMap() {
        // Remove old dots
        miniMapDots.forEach { $0.removeFromSuperview() }
        miniMapDots.removeAll()
        
        guard let gameScene = gameScene else { return }
        
        let mapWidth = Float(gameScene.cityMap.width)
        let mapHeight = Float(gameScene.cityMap.height)
        let miniMapSize: CGFloat = 120
        let mapArea: CGFloat = miniMapSize - 20  // Leave space for title and borders
        
        // Helper function to convert world position to mini-map coordinates
        func worldToMiniMap(x: Float, z: Float) -> (CGFloat, CGFloat) {
            let normalizedX = CGFloat(x / mapWidth)
            let normalizedZ = CGFloat(z / mapHeight)
            let dotX = normalizedX * mapArea + 10
            let dotY = normalizedZ * mapArea + 15  // +15 to account for title
            return (dotX, dotY)
        }
        
        // Add blue dots for each unsaved hostage
        for hostage in gameScene.hostages where hostage.state != .saved {
            let pos = hostage.node.position
            let (dotX, dotY) = worldToMiniMap(x: pos.x, z: pos.z)
            
            let dot = UIView()
            dot.frame = CGRect(x: dotX - 4, y: dotY - 4, width: 8, height: 8)
            dot.backgroundColor = UIColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0)  // Bright blue
            dot.layer.cornerRadius = 4
            dot.layer.borderWidth = 1
            dot.layer.borderColor = UIColor.white.cgColor
            
            miniMapView.addSubview(dot)
            miniMapDots.append(dot)
        }
        
        // Add or update player position dot (white)
        if let ballNode = gameScene.ballNode {
            let playerPos = ballNode.presentation.position
            let (playerX, playerY) = worldToMiniMap(x: playerPos.x, z: playerPos.z)
            
            // Create player dot if it doesn't exist
            if miniMapPlayerDot == nil {
                let playerDot = UIView()
                playerDot.frame = CGRect(x: 0, y: 0, width: 10, height: 10)
                playerDot.backgroundColor = UIColor.white
                playerDot.layer.cornerRadius = 5
                playerDot.layer.borderWidth = 2
                playerDot.layer.borderColor = UIColor.black.cgColor
                miniMapView.addSubview(playerDot)
                miniMapPlayerDot = playerDot
            }
            
            // Update player dot position
            miniMapPlayerDot?.frame = CGRect(x: playerX - 5, y: playerY - 5, width: 10, height: 10)
        }
    }
    
    // MARK: - Debug HUD Visibility Control
    
    func updateDebugHUDVisibility(_ shouldShow: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            
            // Toggle visibility of all three debug HUD elements
            self.connectionStatusLabel.isHidden = !shouldShow
            self.visibilityLabel.isHidden = !shouldShow
            self.distanceLabel.isHidden = !shouldShow
        }
    }
    
    // Make view controller first responder to receive keyboard events
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("🎮 GameViewController viewDidAppear - becoming first responder")
        becomeFirstResponder()
        
        // Re-check for controllers when view appears (in case we missed it during init)
        print("🎮 Re-checking for controllers in viewDidAppear...")
        print("🎮 Number of controllers: \(GCController.controllers().count)")
        if controller == nil && !GCController.controllers().isEmpty {
            print("🎮 ⚠️ Controller was nil but controllers are available - reconnecting...")
            if let gameController = GCController.controllers().first {
                connectController(gameController)
            }
        } else if controller != nil {
            print("🎮 ✅ Controller already connected: \(controller?.vendorName ?? "Unknown")")
        } else {
            print("🎮 ❌ No controllers available")
        }
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
    
    // MARK: - Xbox Controller Support
    
    func setupGameController() {
        print("🎮 setupGameController() called")
        
        // Watch for controller connections
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidConnect),
            name: .GCControllerDidConnect,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidDisconnect),
            name: .GCControllerDidDisconnect,
            object: nil
        )
        
        // Check if controller already connected
        print("🎮 Checking for connected controllers...")
        print("🎮 Number of controllers: \(GCController.controllers().count)")
        if let controller = GCController.controllers().first {
            print("🎮 ✅ Controller found: \(controller.vendorName ?? "Unknown")")
            connectController(controller)
        } else {
            print("🎮 ❌ No controller connected")
        }
    }
    
    @objc func controllerDidConnect(_ notification: Notification) {
        print("🎮 Controller CONNECTED notification received!")
        if let controller = notification.object as? GCController {
            print("🎮 Controller: \(controller.vendorName ?? "Unknown")")
            connectController(controller)
        }
    }
    
    @objc func controllerDidDisconnect(_ notification: Notification) {
        print("🎮 Controller DISCONNECTED!")
        controller = nil
    }
    
    func connectController(_ controller: GCController) {
        print("🎮 connectController() called for: \(controller.vendorName ?? "Unknown")")
        self.controller = controller
        
        // Handle extended gamepad (Xbox, PlayStation, etc.)
        if let gamepad = controller.extendedGamepad {
            print("🎮 ✅ Extended gamepad found - setting up handlers")
            
            // Left stick for ball movement
            gamepad.leftThumbstick.valueChangedHandler = { [weak self] (stick, xValue, yValue) in
                // Y is inverted on game controllers
                print("🕹️ Left stick: x=\(xValue), y=\(yValue)")
                self?.gameScene.moveBall(x: xValue, z: -yValue)
            }
            
            // A button for wall climbing (hold to climb)
            gamepad.buttonA.valueChangedHandler = { [weak self] (button, value, pressed) in
                if pressed {
                    self?.gameScene.jumpBall()
                } else {
                    self?.gameScene.releaseJump()
                }
            }
            
            // Optional: Right stick for camera rotation (if you want to add that later)
            // B button rotates camera view by 45 degrees
            gamepad.buttonB.valueChangedHandler = { [weak self] (button, value, pressed) in
                if pressed {
                    self?.gameScene.rotateCameraView()
                }
            }
            
            // X button exits the game
            gamepad.buttonX.valueChangedHandler = { [weak self] (button, value, pressed) in
                if pressed {
                    print("👋 X button pressed - Exiting game")
                    exit(0)
                }
            }
        }
    }
    
    // MARK: - Camera Update Loop
    
    func startCameraUpdateLoop() {
        // Use CADisplayLink for smooth 60fps camera updates
        let displayLink = CADisplayLink(target: self, selector: #selector(updateCamera))
        displayLink.add(to: .main, forMode: .common)
    }
    
    @objc func updateCamera() {
        // Update camera position to follow ball with config values
        gameScene.updateCamera()
        
        // Update enemy AI
        gameScene.updateEnemyAI()
        
        // Update hostage rescue system
        gameScene.updateHostages()
        
        // Update mini-map (every frame to show real-time positions)
        updateMiniMap()
        
        // Update ball movement from controller input (if connected)
        if controller != nil {
            gameScene.updateBallPhysics()
        }
    }
    
    // MARK: - Game Over UI
    
    var gameOverView: UIView?
    var isPaused: Bool = false
    
    func setupGameOverCallback() {
        // Set up callback to be notified when game over occurs
        gameScene.onGameOver = { [weak self] in
            self?.showGameOver()
        }
    }
    
    func showGameOver() {
        logger.info("Game over triggered")
        
        // Don't create multiple game over views
        if gameOverView != nil {
            logger.debug("Game over view already exists")
            return
        }
        
        // Pause the game
        isPaused = true
        sceneView.scene?.isPaused = true
        
        // Create semi-transparent overlay
        let overlay = UIView(frame: view.bounds)
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.isUserInteractionEnabled = true  // Enable touch events
        
        // Create game over container
        let containerView = UIView()
        containerView.backgroundColor = UIColor.darkGray.withAlphaComponent(0.95)
        containerView.layer.cornerRadius = 20
        containerView.layer.borderWidth = 3
        containerView.layer.borderColor = UIColor.red.cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.isUserInteractionEnabled = true  // Enable touch events
        
        // Game over title
        let titleLabel = UILabel()
        titleLabel.text = "GAME OVER"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 48)
        titleLabel.textColor = .red
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Message label
        let messageLabel = UILabel()
        messageLabel.text = "You were caught by an enemy!"
        messageLabel.font = UIFont.systemFont(ofSize: 20)
        messageLabel.textColor = .white
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Restart button
        let restartButton = UIButton(type: .system)
        restartButton.setTitle("PLAY AGAIN", for: .normal)
        restartButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 28)
        restartButton.setTitleColor(.white, for: .normal)
        restartButton.backgroundColor = UIColor.systemBlue
        restartButton.layer.cornerRadius = 10
        restartButton.layer.borderWidth = 3
        restartButton.layer.borderColor = UIColor.yellow.cgColor
        restartButton.translatesAutoresizingMaskIntoConstraints = false
        restartButton.isUserInteractionEnabled = true  // Enable touch events
        restartButton.addTarget(self, action: #selector(restartGame), for: .touchUpInside)
        
        // Add highlight effect for touch feedback
        restartButton.addTarget(self, action: #selector(buttonTouchDown), for: .touchDown)
        restartButton.addTarget(self, action: #selector(buttonTouchUp), for: [.touchUpInside, .touchUpOutside])
        
        // Restart button created
        
        // Add subviews
        containerView.addSubview(titleLabel)
        containerView.addSubview(messageLabel)
        containerView.addSubview(restartButton)
        overlay.addSubview(containerView)
        view.addSubview(overlay)
        
        // Store reference for removal later
        gameOverView = overlay
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Overlay fills entire view
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Container centered in overlay
            containerView.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 400),
            containerView.heightAnchor.constraint(equalToConstant: 300),
            
            // Title at top of container
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Message below title
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            messageLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Restart button at bottom
            restartButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -40),
            restartButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            restartButton.widthAnchor.constraint(equalToConstant: 200),
            restartButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // Animate in
        overlay.alpha = 0
        UIView.animate(withDuration: 0.3) {
            overlay.alpha = 1.0
        }
        
        logger.info("Game over UI displayed")
    }
    
    @objc func buttonTouchDown(_ sender: UIButton) {
        sender.alpha = 0.5
    }
    
    @objc func buttonTouchUp(_ sender: UIButton) {
        sender.alpha = 1.0
    }
    
    @objc func restartGame() {
        logger.info("Game restarted")
        NSLog("🔄🔄🔄 RESTART BUTTON TAPPED! 🔄🔄🔄")
        
        // Reset game over flag in scene
        gameScene.resetGameOver()
        
        // Remove game over UI
        if let overlay = self.gameOverView {
            UIView.animate(withDuration: 0.2, animations: {
                overlay.alpha = 0
            }) { _ in
                overlay.removeFromSuperview()
                self.gameOverView = nil
            }
        } else {
        }
        
        // Unpause the game
        isPaused = false
        sceneView.scene?.isPaused = false
        
        // Reset ball position to starting location (top-right corner)
        let mapWidth = Float(gameScene.cityMap.width)
        let mapHeight = Float(gameScene.cityMap.height)
        gameScene.ballNode.position = SCNVector3(x: mapWidth - 5, y: 5, z: mapHeight - 5)
        gameScene.ballNode.physicsBody?.velocity = SCNVector3(0, 0, 0)
        gameScene.ballNode.physicsBody?.angularVelocity = SCNVector4(0, 0, 0, 0)
        
        // Reset enemy positions to corners
        gameScene.createEnemyBalls()
        
    }
    
    func showLevelCompleteMessage() {
        // Create overlay container
        let overlayView = UIView(frame: view.bounds)
        overlayView.backgroundColor = UIColor(white: 0, alpha: 0.7)
        overlayView.alpha = 0
        view.addSubview(overlayView)
        
        // Create level complete label
        let messageLabel = UILabel()
        messageLabel.text = "🎉 LEVEL \(gameScene.currentLevel - 1) COMPLETE! 🎉"
        messageLabel.font = UIFont.boldSystemFont(ofSize: 36)
        messageLabel.textColor = .green
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(messageLabel)
        
        // Create next level label
        let nextLevelLabel = UILabel()
        nextLevelLabel.text = "Level \(gameScene.currentLevel) Starting..."
        nextLevelLabel.font = UIFont.systemFont(ofSize: 24)
        nextLevelLabel.textColor = .cyan
        nextLevelLabel.textAlignment = .center
        nextLevelLabel.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(nextLevelLabel)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            messageLabel.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor, constant: -30),
            messageLabel.leadingAnchor.constraint(greaterThanOrEqualTo: overlayView.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(lessThanOrEqualTo: overlayView.trailingAnchor, constant: -20),
            
            nextLevelLabel.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            nextLevelLabel.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 20),
            nextLevelLabel.leadingAnchor.constraint(greaterThanOrEqualTo: overlayView.leadingAnchor, constant: 20),
            nextLevelLabel.trailingAnchor.constraint(lessThanOrEqualTo: overlayView.trailingAnchor, constant: -20)
        ])
        
        // Animate in
        UIView.animate(withDuration: 0.3) {
            overlayView.alpha = 1.0
        }
        
        // Auto-dismiss after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            UIView.animate(withDuration: 0.3, animations: {
                overlayView.alpha = 0
            }) { _ in
                overlayView.removeFromSuperview()
            }
        }
    }
}
