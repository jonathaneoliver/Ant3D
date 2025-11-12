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
        connectionStatusLabel.textAlignment = .left
        connectionStatusLabel.numberOfLines = 1
        connectionStatusLabel.text = " ⏳ Connecting to config server... "
        connectionStatusLabel.layer.cornerRadius = 4
        connectionStatusLabel.layer.masksToBounds = true
        connectionStatusLabel.adjustsFontSizeToFitWidth = true
        connectionStatusLabel.minimumScaleFactor = 0.7
        
        // Add padding
        connectionStatusLabel.layoutMargins = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        
        view.addSubview(connectionStatusLabel)
        
        // Position at top-left corner with safe area insets
        NSLayoutConstraint.activate([
            connectionStatusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            connectionStatusLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            connectionStatusLabel.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        print("GameViewController: HUD label created and added to view")
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
        
        view.addSubview(visibilityLabel)
        
        // Position at bottom-right corner with safe area insets
        NSLayoutConstraint.activate([
            visibilityLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            visibilityLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
            visibilityLabel.heightAnchor.constraint(equalToConstant: 28)
        ])
        
        print("GameViewController: Visibility HUD label created and added to view")
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
        
        view.addSubview(distanceLabel)
        
        // Position at bottom-left corner with safe area insets
        NSLayoutConstraint.activate([
            distanceLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            distanceLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            distanceLabel.heightAnchor.constraint(equalToConstant: 28)
        ])
        
        print("GameViewController: Distance HUD label created and added to view")
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
            
            // A button to jump
            gamepad.buttonA.valueChangedHandler = { [weak self] (button, value, pressed) in
                if pressed {
                    print("A button pressed - Jump!")
                    self?.gameScene.jumpBall()
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
