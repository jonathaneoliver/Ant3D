import UIKit
import SceneKit
import os.log

// Create logger for HUDManager
private let hudLogger = Logger(subsystem: "com.example.AntAttack3D", category: "HUDManager")

/// Manages all HUD elements in the game
class HUDManager {
    // MARK: - Properties
    
    weak var view: UIView?
    weak var gameScene: GameScene3D?
    
    // HUD Elements
    private var debugLabel: UILabel!
    private var connectionStatusLabel: UILabel!
    private var visibilityLabel: UILabel!
    private var distanceLabel: UILabel!
    private var hostageStackView: UIStackView!
    private var hostageFaces: [UILabel] = []
    private var scoreLabel: UILabel!
    private var levelLabel: UILabel!
    private var miniMapView: UIView!
    private var miniMapDots: [UIView] = []
    private var miniMapPlayerDot: UIView?
    private var miniMapSafeMatIndicator: UIView?
    private var gameOverView: UIView?
    
    // State
    var isPaused: Bool = false
    
    // Callbacks
    var onRestartGame: (() -> Void)?
    
    // MARK: - Setup
    
    func setup() {
        guard view != nil else { return }
        
        setupBigDebugLabel()
        setupConnectionStatusHUD()
        setupVisibilityHUD()
        setupDistanceHUD()
        setupHostageHUD()
        setupLevelHUD()
        setupScoreHUD()
        setupMiniMap()
        
        // Default: hide debug HUDs
        updateDebugHUDVisibility(false)
    }
    
    func cleanup() {
        debugLabel?.removeFromSuperview()
        connectionStatusLabel?.removeFromSuperview()
        visibilityLabel?.removeFromSuperview()
        distanceLabel?.removeFromSuperview()
        hostageStackView?.removeFromSuperview()
        scoreLabel?.removeFromSuperview()
        levelLabel?.removeFromSuperview()
        miniMapView?.removeFromSuperview()
        gameOverView?.removeFromSuperview()
    }
    
    // MARK: - Debug Label
    
    private func setupBigDebugLabel() {
        guard let view = view else { return }
        
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
    
    private func setupConnectionStatusHUD() {
        guard let view = view else { return }
        
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
        
        // Rotate 90 degrees counter-clockwise
        connectionStatusLabel.transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 2)
        
        view.addSubview(connectionStatusLabel)
        
        NSLayoutConstraint.activate([
            connectionStatusLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 120),
            connectionStatusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            connectionStatusLabel.widthAnchor.constraint(equalToConstant: 200),
            connectionStatusLabel.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    func updateConnectionStatus(_ isConnected: Bool, serverURL: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if isConnected {
                self.connectionStatusLabel.text = " ● \(serverURL) "
                self.connectionStatusLabel.textColor = UIColor(red: 0.3, green: 1.0, blue: 0.3, alpha: 1.0)
                self.connectionStatusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            } else {
                self.connectionStatusLabel.text = " ○ \(serverURL) "
                self.connectionStatusLabel.textColor = UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
                self.connectionStatusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            }
        }
    }
    
    // MARK: - Ball Visibility HUD
    
    private func setupVisibilityHUD() {
        guard let view = view else { return }
        
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
        
        // Rotate 90 degrees counter-clockwise
        visibilityLabel.transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 2)
        
        view.addSubview(visibilityLabel)
        
        NSLayoutConstraint.activate([
            visibilityLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 330),
            visibilityLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            visibilityLabel.widthAnchor.constraint(equalToConstant: 140),
            visibilityLabel.heightAnchor.constraint(equalToConstant: 28)
        ])
    }
    
    func updateBallVisibility(_ isVisible: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if isVisible {
                self.visibilityLabel.text = " 🎯 Ball: VISIBLE "
                self.visibilityLabel.textColor = UIColor(red: 0.3, green: 1.0, blue: 0.3, alpha: 1.0)
                self.visibilityLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            } else {
                self.visibilityLabel.text = " ⚠️ Ball: HIDDEN "
                self.visibilityLabel.textColor = UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
                self.visibilityLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            }
        }
    }
    
    // MARK: - Distance HUD
    
    private func setupDistanceHUD() {
        guard let view = view else { return }
        
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
        
        // Rotate 90 degrees counter-clockwise
        distanceLabel.transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 2)
        
        view.addSubview(distanceLabel)
        
        NSLayoutConstraint.activate([
            distanceLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 480),
            distanceLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            distanceLabel.widthAnchor.constraint(equalToConstant: 120),
            distanceLabel.heightAnchor.constraint(equalToConstant: 28)
        ])
    }
    
    func updateDistance(_ distance: Float) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.distanceLabel.text = String(format: " 📏 Dist: %.1f ", distance)
            self.distanceLabel.textColor = .cyan
            self.distanceLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        }
    }
    
    // MARK: - Hostage Rescue HUD
    
    private func setupHostageHUD() {
        guard let view = view else { return }
        
        hostageStackView = UIStackView()
        hostageStackView.translatesAutoresizingMaskIntoConstraints = false
        hostageStackView.axis = .horizontal
        hostageStackView.spacing = 2
        hostageStackView.alignment = .center
        hostageStackView.distribution = .equalSpacing
        hostageStackView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        hostageStackView.layer.cornerRadius = 4
        hostageStackView.layer.masksToBounds = true
        hostageStackView.layoutMargins = UIEdgeInsets(top: 3, left: 5, bottom: 3, right: 5)
        hostageStackView.isLayoutMarginsRelativeArrangement = true
        
        view.addSubview(hostageStackView)
        
        NSLayoutConstraint.activate([
            hostageStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 2),
            hostageStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 2),
            hostageStackView.heightAnchor.constraint(equalToConstant: 28)
        ])
        
        // Initialize with 5 faces (will be updated dynamically)
        for _ in 0..<5 {
            let faceLabel = UILabel()
            faceLabel.font = UIFont.systemFont(ofSize: 20)
            faceLabel.text = "😢"
            faceLabel.textAlignment = .center
            hostageStackView.addArrangedSubview(faceLabel)
            hostageFaces.append(faceLabel)
        }
    }
    
    func updateHostageCount(_ saved: Int, _ total: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Ensure we have the right number of faces
            if self.hostageFaces.count != total {
                // Remove all existing faces
                self.hostageFaces.forEach { $0.removeFromSuperview() }
                self.hostageFaces.removeAll()
                
                // Create new faces for the actual total
                for _ in 0..<total {
                    let faceLabel = UILabel()
                    faceLabel.font = UIFont.systemFont(ofSize: 32)
                    faceLabel.text = "😢"
                    faceLabel.textAlignment = .center
                    self.hostageStackView.addArrangedSubview(faceLabel)
                    self.hostageFaces.append(faceLabel)
                }
            }
            
            // Update face icons
            for (index, faceLabel) in self.hostageFaces.enumerated() {
                if index < saved {
                    faceLabel.text = "😊"  // Happy face for rescued
                } else {
                    faceLabel.text = "😢"  // Sad face for not-yet-rescued
                }
            }
            
            // Change background color based on status
            if saved == total && total > 0 {
                self.hostageStackView.backgroundColor = UIColor.green.withAlphaComponent(0.3)
            } else {
                self.hostageStackView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            }
        }
    }
    
    // MARK: - Score HUD
    
    private func setupScoreHUD() {
        guard let view = view else { return }
        
        scoreLabel = UILabel()
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false
        scoreLabel.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .bold)
        scoreLabel.textColor = .yellow
        scoreLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        scoreLabel.textAlignment = .center
        scoreLabel.numberOfLines = 1
        scoreLabel.text = " 🏆 0 "
        scoreLabel.layer.cornerRadius = 4
        scoreLabel.layer.masksToBounds = true
        scoreLabel.adjustsFontSizeToFitWidth = true
        scoreLabel.minimumScaleFactor = 0.7
        
        view.addSubview(scoreLabel)
        
        NSLayoutConstraint.activate([
            scoreLabel.topAnchor.constraint(equalTo: levelLabel.bottomAnchor, constant: 3),
            scoreLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 2),
            scoreLabel.heightAnchor.constraint(equalToConstant: 22)
        ])
    }
    
    func updateScore(_ score: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.scoreLabel.text = String(format: " 🏆 %d ", score)
            self.scoreLabel.textColor = .yellow
            self.scoreLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        }
    }
    
    // MARK: - Level HUD
    
    private func setupLevelHUD() {
        guard let view = view else { return }
        
        levelLabel = UILabel()
        levelLabel.translatesAutoresizingMaskIntoConstraints = false
        levelLabel.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .bold)
        levelLabel.textColor = .cyan
        levelLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        levelLabel.textAlignment = .center
        levelLabel.numberOfLines = 1
        levelLabel.text = " 🎮 1 "
        levelLabel.layer.cornerRadius = 4
        levelLabel.layer.masksToBounds = true
        levelLabel.adjustsFontSizeToFitWidth = true
        levelLabel.minimumScaleFactor = 0.7
        
        view.addSubview(levelLabel)
        
        NSLayoutConstraint.activate([
            levelLabel.topAnchor.constraint(equalTo: hostageStackView.bottomAnchor, constant: 3),
            levelLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 2),
            levelLabel.heightAnchor.constraint(equalToConstant: 22)
        ])
    }
    
    func updateLevel(_ level: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.levelLabel.text = String(format: " 🎮 %d ", level)
            self.levelLabel.textColor = .cyan
            self.levelLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        }
    }
    
    // MARK: - Mini-Map HUD
    
    private func setupMiniMap() {
        guard let view = view else { return }
        
        miniMapView = UIView()
        miniMapView.translatesAutoresizingMaskIntoConstraints = false
        miniMapView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        miniMapView.layer.cornerRadius = 6
        miniMapView.layer.masksToBounds = true
        miniMapView.layer.borderWidth = GameConstants.UI.buttonBorderWidth
        miniMapView.layer.borderColor = UIColor.cyan.cgColor
        miniMapView.isUserInteractionEnabled = false
        
        view.addSubview(miniMapView)
        
        let mapSize: CGFloat = 90
        NSLayoutConstraint.activate([
            miniMapView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -2),
            miniMapView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 2),
            miniMapView.widthAnchor.constraint(equalToConstant: mapSize),
            miniMapView.heightAnchor.constraint(equalToConstant: mapSize)
        ])
    }
    
    func updateMiniMap() {
        // Remove old dots
        miniMapDots.forEach { $0.removeFromSuperview() }
        miniMapDots.removeAll()
        
        guard let gameScene = gameScene else { return }
        
        let mapWidth = Float(gameScene.cityMap.width)
        let mapHeight = Float(gameScene.cityMap.height)
        let miniMapSize: CGFloat = 90
        let mapArea: CGFloat = miniMapSize - 12
        
        let cameraAngle = gameScene.cameraOrbitAngle
        let cameraRadians = CGFloat(cameraAngle * Float.pi / 180.0)
        
        // Helper function to convert world position to mini-map coordinates with rotation
        func worldToMiniMap(x: Float, z: Float) -> (CGFloat, CGFloat) {
            let normalizedX = CGFloat(x / mapWidth)
            let normalizedZ = CGFloat(z / mapHeight)
            
            let centeredX = normalizedX - 0.5
            let centeredZ = normalizedZ - 0.5
            
            let rotatedX = centeredX * cos(cameraRadians) - centeredZ * sin(cameraRadians)
            let rotatedZ = centeredX * sin(cameraRadians) + centeredZ * cos(cameraRadians)
            
            let dotX = (rotatedX + 0.5) * mapArea + 6
            let dotY = (rotatedZ + 0.5) * mapArea + 6
            return (dotX, dotY)
        }
        
        // Add safe mat indicator
        let safeMatPos = gameScene.safeMatPosition
        let (matX, matY) = worldToMiniMap(x: safeMatPos.x, z: safeMatPos.z)
        let matSize: CGFloat = 12
        
        if miniMapSafeMatIndicator == nil {
            let safeMatView = UIView()
            safeMatView.backgroundColor = UIColor(red: 0.0, green: 0.3, blue: 1.0, alpha: 0.6)
            safeMatView.layer.cornerRadius = 2
            safeMatView.layer.borderWidth = 1
            safeMatView.layer.borderColor = UIColor.white.cgColor
            miniMapView.addSubview(safeMatView)
            miniMapSafeMatIndicator = safeMatView
        }
        
        miniMapSafeMatIndicator?.frame = CGRect(x: matX - matSize/2, y: matY - matSize/2, width: matSize, height: matSize)
        
        // Add blue dots for each unsaved hostage
        for hostage in gameScene.hostages where hostage.state != .saved {
            let pos = hostage.node.position
            let (dotX, dotY) = worldToMiniMap(x: pos.x, z: pos.z)
            
            let dot = UIView()
            dot.frame = CGRect(x: dotX - 3, y: dotY - 3, width: 6, height: 6)
            dot.backgroundColor = UIColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0)
            dot.layer.cornerRadius = 3
            dot.layer.borderWidth = 0.5
            dot.layer.borderColor = UIColor.white.cgColor
            
            miniMapView.addSubview(dot)
            miniMapDots.append(dot)
        }
        
        // Add or update player position dot
        if let ballNode = gameScene.ballNode {
            let playerPos = ballNode.presentation.position
            let (playerX, playerY) = worldToMiniMap(x: playerPos.x, z: playerPos.z)
            
            if miniMapPlayerDot == nil {
                let playerDot = UIView()
                playerDot.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
                playerDot.backgroundColor = UIColor.white
                playerDot.layer.cornerRadius = 4
                playerDot.layer.borderWidth = 1
                playerDot.layer.borderColor = UIColor.black.cgColor
                miniMapView.addSubview(playerDot)
                miniMapPlayerDot = playerDot
            }
            
            miniMapPlayerDot?.frame = CGRect(x: playerX - 4, y: playerY - 4, width: 8, height: 8)
        }
    }
    
    // MARK: - Debug HUD Visibility Control
    
    func updateDebugHUDVisibility(_ shouldShow: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.connectionStatusLabel.isHidden = !shouldShow
            self.visibilityLabel.isHidden = !shouldShow
            self.distanceLabel.isHidden = !shouldShow
        }
    }
    
    // MARK: - Game Over UI
    
    func showGameOver() {
        guard let view = view, let gameScene = gameScene else { return }
        
        hudLogger.info("Game over triggered")
        
        // Don't create multiple game over views
        if gameOverView != nil {
            hudLogger.debug("Game over view already exists")
            return
        }
        
        // Pause the game
        isPaused = true
        
        // Create semi-transparent overlay
        let overlay = UIView(frame: view.bounds)
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.isUserInteractionEnabled = true
        
        // Create game over container
        let containerView = UIView()
        containerView.backgroundColor = UIColor.darkGray.withAlphaComponent(0.95)
        containerView.layer.cornerRadius = 20
        containerView.layer.borderWidth = 3
        containerView.layer.borderColor = UIColor.red.cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.isUserInteractionEnabled = true
        
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
        restartButton.isUserInteractionEnabled = true
        restartButton.addTarget(self, action: #selector(restartGameTapped), for: .touchUpInside)
        restartButton.addTarget(self, action: #selector(buttonTouchDown), for: .touchDown)
        restartButton.addTarget(self, action: #selector(buttonTouchUp), for: [.touchUpInside, .touchUpOutside])
        
        // Add subviews
        containerView.addSubview(titleLabel)
        containerView.addSubview(messageLabel)
        containerView.addSubview(restartButton)
        overlay.addSubview(containerView)
        view.addSubview(overlay)
        
        // Store reference
        gameOverView = overlay
        
        // Layout constraints
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            containerView.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 400),
            containerView.heightAnchor.constraint(equalToConstant: 300),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            messageLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
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
        
        hudLogger.info("Game over UI displayed")
    }
    
    @objc private func buttonTouchDown(_ sender: UIButton) {
        sender.alpha = 0.5
    }
    
    @objc private func buttonTouchUp(_ sender: UIButton) {
        sender.alpha = 1.0
    }
    
    @objc private func restartGameTapped() {
        hudLogger.info("Game restart requested")
        onRestartGame?()
        hideGameOver()
    }
    
    func hideGameOver() {
        if let overlay = gameOverView {
            UIView.animate(withDuration: 0.2, animations: {
                overlay.alpha = 0
            }) { [weak self] _ in
                overlay.removeFromSuperview()
                self?.gameOverView = nil
            }
        }
        
        isPaused = false
    }
    
    // MARK: - Level Complete Message
    
    func showLevelCompleteMessage() {
        guard let view = view, let gameScene = gameScene else { return }
        
        let overlayView = UIView(frame: view.bounds)
        overlayView.backgroundColor = UIColor(white: 0, alpha: 0.7)
        overlayView.alpha = 0
        view.addSubview(overlayView)
        
        let messageLabel = UILabel()
        messageLabel.text = "🎉 LEVEL \(gameScene.currentLevel - 1) COMPLETE! 🎉"
        messageLabel.font = UIFont.boldSystemFont(ofSize: 36)
        messageLabel.textColor = .green
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(messageLabel)
        
        let nextLevelLabel = UILabel()
        nextLevelLabel.text = "Level \(gameScene.currentLevel) Starting..."
        nextLevelLabel.font = UIFont.systemFont(ofSize: 24)
        nextLevelLabel.textColor = .cyan
        nextLevelLabel.textAlignment = .center
        nextLevelLabel.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(nextLevelLabel)
        
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
