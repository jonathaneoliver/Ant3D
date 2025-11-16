import Foundation
import GameController
import CoreMotion
import UIKit

/// Manages all input sources (game controller, motion, on-screen buttons)
/// Handles input priority and delegates commands to the game scene
class InputManager {
    
    // MARK: - Properties
    
    weak var gameScene: GameScene3D?
    weak var viewController: UIViewController?
    
    // Game controller
    private var controller: GCController?
    private var controllerHasBeenUsed: Bool = false
    
    // Motion controls
    private var motionManager: CMMotionManager?
    private var motionUpdateTimer: Timer?
    private var lastMotionX: Float = 0
    private var lastMotionZ: Float = 0
    
    // On-screen buttons
    var climbButton: UIButton?
    var rotateButton: UIButton?
    private var buttonsHidden: Bool = false
    
    // Input state
    private var currentMoveX: Float = 0
    private var currentMoveZ: Float = 0
    private var isClimbPressed: Bool = false
    
    // MARK: - Callbacks
    
    var onCameraRotate: (() -> Void)?
    var onReturnToTitle: (() -> Void)?
    
    // MARK: - Setup
    
    func setup() {
        setupGameController()
        setupMotionControls()
        setupOnScreenButtons()
    }
    
    func cleanup() {
        // Remove controller observers
        NotificationCenter.default.removeObserver(self, name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.removeObserver(self, name: .GCControllerDidDisconnect, object: nil)
        
        // Stop motion updates
        motionUpdateTimer?.invalidate()
        motionUpdateTimer = nil
        motionManager?.stopAccelerometerUpdates()
        motionManager = nil
        
        // Remove buttons
        climbButton?.removeFromSuperview()
        rotateButton?.removeFromSuperview()
        climbButton = nil
        rotateButton = nil
    }
    
    // MARK: - Game Controller
    
    private func setupGameController() {
        print("🎮 InputManager: Setting up game controller support")
        
        // Watch for controller connections
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let controller = notification.object as? GCController {
                print("🎮 Controller CONNECTED: \(controller.vendorName ?? "Unknown")")
                self?.connectController(controller)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🎮 Controller DISCONNECTED")
            self?.controller = nil
        }
        
        // Check if controller already connected
        if let controller = GCController.controllers().first {
            print("🎮 Controller already connected: \(controller.vendorName ?? "Unknown")")
            connectController(controller)
        }
    }
    
    private func connectController(_ controller: GCController) {
        self.controller = controller
        
        guard let gamepad = controller.extendedGamepad else { return }
        print("🎮 Extended gamepad configured")
        
        // Left stick for ball movement
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] (stick, xValue, yValue) in
            guard let self = self else { return }
            
            // Mark controller as used when significant input detected
            if abs(xValue) > 0.1 || abs(yValue) > 0.1 {
                self.controllerHasBeenUsed = true
                self.hideOnScreenButtons()
            }
            
            // Y is inverted on game controllers
            self.currentMoveX = xValue
            self.currentMoveZ = -yValue
            self.gameScene?.moveBall(x: xValue, z: -yValue)
        }
        
        // A button for wall climbing (hold to climb)
        gamepad.buttonA.valueChangedHandler = { [weak self] (button, value, pressed) in
            guard let self = self else { return }
            
            self.controllerHasBeenUsed = true
            self.hideOnScreenButtons()
            
            if pressed {
                self.isClimbPressed = true
                self.gameScene?.jumpBall()
            } else {
                self.isClimbPressed = false
                self.gameScene?.releaseJump()
            }
        }
        
        // B button rotates camera view by 45 degrees
        gamepad.buttonB.valueChangedHandler = { [weak self] (button, value, pressed) in
            if pressed {
                self?.controllerHasBeenUsed = true
                self?.hideOnScreenButtons()
                self?.gameScene?.rotateCameraView()
                self?.onCameraRotate?()
            }
        }
        
        // X button returns to title screen
        gamepad.buttonX.valueChangedHandler = { [weak self] (button, value, pressed) in
            if pressed {
                self?.controllerHasBeenUsed = true
                self?.hideOnScreenButtons()
                print("👋 X button pressed - Returning to title screen")
                self?.onReturnToTitle?()
            }
        }
    }
    
    // MARK: - Motion Controls
    
    private func setupMotionControls() {
        motionManager = CMMotionManager()
        guard let motionManager = motionManager else { return }
        
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = GameConstants.Movement.motionUpdateRate
            motionManager.startAccelerometerUpdates()
            
            // Use timer to update motion controls
            motionUpdateTimer = Timer.scheduledTimer(withTimeInterval: GameConstants.Movement.motionUpdateRate, repeats: true) { [weak self] _ in
                self?.updateMotionControls()
            }
            
            print("📱 Motion controls enabled")
        } else {
            print("📱 Accelerometer not available")
        }
    }
    
    private func updateMotionControls() {
        // Don't use motion controls if a game controller has been actively used
        if controllerHasBeenUsed {
            return
        }
        
        guard let motionManager = motionManager,
              let data = motionManager.accelerometerData else { return }
        
        // In landscape orientation:
        // - device.acceleration.x (pitch forward/back) controls Z axis (forward/back)
        // - device.acceleration.y (roll left/right) controls X axis (left/right)
        
        // Sensitivity: 10° tilt = 100% speed
        let sensitivity: Float = 1.0 / sin(GameConstants.toRadians(GameConstants.Movement.motionSensitivity))
        
        // Map accelerometer to movement (landscape mode) - INVERTED for correct direction
        let moveX = -Float(data.acceleration.y) * sensitivity  // Roll left/right (inverted)
        let moveZ = -Float(data.acceleration.x) * sensitivity  // Pitch forward/back (inverted)
        
        // Clamp to -1...1
        let clampedX = max(-1.0, min(1.0, moveX))
        let clampedZ = max(-1.0, min(1.0, moveZ))
        
        // Store for tracking
        lastMotionX = clampedX
        lastMotionZ = clampedZ
        
        // Pass to game scene
        gameScene?.moveBall(x: clampedX, z: clampedZ)
    }
    
    // MARK: - On-Screen Buttons
    
    private func setupOnScreenButtons() {
        guard let view = viewController?.view else { return }
        
        // Climb button (bottom-right, blue)
        let climbBtn = UIButton(type: .system)
        climbBtn.setTitle("🧗", for: .normal)
        climbBtn.titleLabel?.font = UIFont.systemFont(ofSize: 40)
        climbBtn.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.7)
        climbBtn.layer.cornerRadius = 35
        climbBtn.translatesAutoresizingMaskIntoConstraints = false
        climbBtn.addTarget(self, action: #selector(climbButtonPressed), for: .touchDown)
        climbBtn.addTarget(self, action: #selector(climbButtonReleased), for: [.touchUpInside, .touchUpOutside])
        view.addSubview(climbBtn)
        
        // Camera rotate button (above climb button, green)
        let rotateBtn = UIButton(type: .system)
        rotateBtn.setTitle("🔄", for: .normal)
        rotateBtn.titleLabel?.font = UIFont.systemFont(ofSize: 40)
        rotateBtn.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.7)
        rotateBtn.layer.cornerRadius = 35
        rotateBtn.translatesAutoresizingMaskIntoConstraints = false
        rotateBtn.addTarget(self, action: #selector(rotateButtonPressed), for: .touchUpInside)
        view.addSubview(rotateBtn)
        
        NSLayoutConstraint.activate([
            // Climb button - absolute bottom right corner
            climbBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            climbBtn.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
            climbBtn.widthAnchor.constraint(equalToConstant: 70),
            climbBtn.heightAnchor.constraint(equalToConstant: 70),
            
            // Rotate button - above climb button
            rotateBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            rotateBtn.bottomAnchor.constraint(equalTo: climbBtn.topAnchor, constant: -10),
            rotateBtn.widthAnchor.constraint(equalToConstant: 70),
            rotateBtn.heightAnchor.constraint(equalToConstant: 70)
        ])
        
        climbButton = climbBtn
        rotateButton = rotateBtn
        
        print("🎮 On-screen buttons created")
    }
    
    @objc private func climbButtonPressed() {
        isClimbPressed = true
        gameScene?.jumpBall()
        climbButton?.alpha = 0.5
    }
    
    @objc private func climbButtonReleased() {
        isClimbPressed = false
        gameScene?.releaseJump()
        climbButton?.alpha = 1.0
    }
    
    @objc private func rotateButtonPressed() {
        gameScene?.rotateCameraView()
        onCameraRotate?()
    }
    
    func hideOnScreenButtons() {
        guard !buttonsHidden else { return }
        
        UIView.animate(withDuration: 0.3) { [weak self] in
            self?.climbButton?.alpha = 0
            self?.rotateButton?.alpha = 0
        }
        
        buttonsHidden = true
    }
    
    func showOnScreenButtons() {
        guard buttonsHidden else { return }
        
        UIView.animate(withDuration: 0.3) { [weak self] in
            self?.climbButton?.alpha = 1.0
            self?.rotateButton?.alpha = 1.0
        }
        
        buttonsHidden = false
    }
}
