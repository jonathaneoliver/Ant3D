import SceneKit
import UIKit
import GameController
import os.log

class GameViewController3D: UIViewController {
    
    var sceneView: SCNView!
    var gameScene: GameScene3D!
    var connectionStatusLabel: UILabel!
    var debugLabel: UILabel!  // Big visible debug label
    var visibilityLabel: UILabel!  // Ball visibility indicator
    var distanceLabel: UILabel!  // Camera distance from ball
    var axisView: SCNView!  // 3D axis indicator
    var controller: GCController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // File log
        FileLogger.shared.log("🎮 GameViewController.viewDidLoad() called")
        
        // Triple-log to ensure visibility
        print("========================================")
        print("🎮 GameViewController viewDidLoad started")
        print("========================================")
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
        
        print("✅ SceneView created and added to view")
        NSLog("✅ SceneView created and added to view")
        FileLogger.shared.log("✅ SceneView created")
        updateDebugLabel("SceneView created")
        
        // Create the game scene
        gameScene = GameScene3D()
        sceneView.scene = gameScene
        gameScene.sceneView = sceneView  // Give scene a reference to view for hit testing
        
        print("✅ GameScene created and set")
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
        
        // Setup config update listener for debug HUD visibility AND forward to game scene
        ConfigManager.shared.onConfigUpdate = { [weak self] config in
            self?.updateDebugHUDVisibility(config.showDebugHUD)
            // Forward config update to game scene for camera/lighting updates
            self?.gameScene.onConfigReceived(config)
        }
        
        // Setup Xbox controller
        setupGameController()
        updateDebugLabel("Controller setup complete")
        
        // Start camera update loop
        startCameraUpdateLoop()
        
        print("========================================")
        print("✅ GameViewController viewDidLoad COMPLETE")
        print("========================================")
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
        print("========================================")
        print("GameViewController: setupConnectionStatusHUD called")
        print("========================================")
        
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
        
        print("GameViewController: HUD label created, rotated 90°, and added to far left edge below time")
    }
    
    func updateConnectionStatus(_ isConnected: Bool, serverURL: String) {
        print("GameViewController: Updating HUD - connected: \(isConnected), server: \(serverURL)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if isConnected {
                self.connectionStatusLabel.text = " ● \(serverURL) "
                self.connectionStatusLabel.textColor = UIColor(red: 0.3, green: 1.0, blue: 0.3, alpha: 1.0) // Bright green
                self.connectionStatusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
                print("GameViewController: HUD updated to CONNECTED (green)")
            } else {
                self.connectionStatusLabel.text = " ○ \(serverURL) "
                self.connectionStatusLabel.textColor = UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0) // Bright red
                self.connectionStatusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
                print("GameViewController: HUD updated to DISCONNECTED (red)")
            }
        }
    }
    
    // MARK: - Ball Visibility HUD
    
    func setupVisibilityHUD() {
        print("GameViewController: setupVisibilityHUD called")
        
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
        
        print("GameViewController: Visibility HUD label created, rotated 90°, and added to far left edge")
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
                print("GameViewController: Visibility HUD updated to HIDDEN (red)")
            }
        }
    }
    
    // MARK: - Distance HUD
    
    func setupDistanceHUD() {
        print("GameViewController: setupDistanceHUD called")
        
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
        
        print("GameViewController: Distance HUD label created, rotated 90°, and added to far left edge")
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
    
    // MARK: - Debug HUD Visibility Control
    
    func updateDebugHUDVisibility(_ shouldShow: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            print("GameViewController: \(shouldShow ? "Showing" : "Hiding") debug HUD elements")
            
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
    
    // MARK: - Xbox Controller Support
    
    func setupGameController() {
        print("Setting up game controller support")
        
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
        if let controller = GCController.controllers().first {
            connectController(controller)
        }
    }
    
    @objc func controllerDidConnect(_ notification: Notification) {
        if let controller = notification.object as? GCController {
            print("Controller connected: \(controller.vendorName ?? "Unknown")")
            connectController(controller)
        }
    }
    
    @objc func controllerDidDisconnect(_ notification: Notification) {
        print("Controller disconnected")
        controller = nil
    }
    
    func connectController(_ controller: GCController) {
        self.controller = controller
        
        // Handle extended gamepad (Xbox, PlayStation, etc.)
        if let gamepad = controller.extendedGamepad {
            print("Extended gamepad connected")
            
            // Left stick for ball movement
            gamepad.leftThumbstick.valueChangedHandler = { [weak self] (stick, xValue, yValue) in
                // Y is inverted on game controllers
                self?.gameScene.moveBall(x: xValue, z: -yValue)
            }
            
            // A button for wall climbing (hold to climb)
            gamepad.buttonA.valueChangedHandler = { [weak self] (button, value, pressed) in
                if pressed {
                    print("A button pressed - Climb mode activated!")
                    self?.gameScene.jumpBall()
                } else {
                    print("A button released - Climb mode deactivated!")
                    self?.gameScene.releaseJump()
                }
            }
            
            // Optional: Right stick for camera rotation (if you want to add that later)
            // B button could be used for something else
            gamepad.buttonB.valueChangedHandler = { [weak self] (button, value, pressed) in
                if pressed {
                    print("B button pressed")
                    // Could add special action here
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
        
        // Update ball movement from controller input (if connected)
        if controller != nil {
            gameScene.updateBallPhysics()
        }
    }
}
