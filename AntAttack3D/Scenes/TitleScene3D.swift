import UIKit
import GameKit

class TitleScene3D: UIViewController {
    var onStartGame: (() -> Void)?
    var onShowLeaderboard: (() -> Void)?
    var onShowAbout: (() -> Void)?
    
    private var titleLabel: UILabel!
    private var startButton: UIButton!
    private var highScoreButton: UIButton!
    private var aboutButton: UIButton!
    private var gameCenterButton: UIButton!
    private var gameCenterStatusLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Dark gradient background (Ant Attack style)
        view.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
        
        // Add subtle animated background
        setupAnimatedBackground()
        
        // Title label
        titleLabel = UILabel()
        titleLabel.text = "ANT ATTACK 3D"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 28)
        titleLabel.textColor = UIColor(red: 1.0, green: 0.9, blue: 0.0, alpha: 1.0) // Gold
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // Add glow effect to title
        titleLabel.layer.shadowColor = UIColor(red: 1.0, green: 0.9, blue: 0.0, alpha: 1.0).cgColor
        titleLabel.layer.shadowOffset = .zero
        titleLabel.layer.shadowRadius = 15
        titleLabel.layer.shadowOpacity = 0.8
        
        // Subtitle
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Rescue the Hostages!"
        subtitleLabel.font = UIFont.systemFont(ofSize: 14)
        subtitleLabel.textColor = UIColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 1.0) // Cyan
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)
        
        // Game Center status label (top right)
        gameCenterStatusLabel = UILabel()
        updateGameCenterStatus()
        gameCenterStatusLabel.font = UIFont.systemFont(ofSize: 12)
        gameCenterStatusLabel.textAlignment = .right
        gameCenterStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(gameCenterStatusLabel)
        
        // Start button
        startButton = createStyledButton(
            text: "START GAME",
            color: UIColor(red: 0.0, green: 0.8, blue: 0.0, alpha: 1.0),
            action: #selector(startGameTapped)
        )
        view.addSubview(startButton)
        
        // High Score button
        highScoreButton = createStyledButton(
            text: "HIGH SCORES",
            color: UIColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 1.0),
            action: #selector(highScoreTapped)
        )
        view.addSubview(highScoreButton)
        
        // About button
        aboutButton = createStyledButton(
            text: "ABOUT",
            color: UIColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0),
            action: #selector(aboutTapped)
        )
        view.addSubview(aboutButton)
        
        // Game Center button
        gameCenterButton = createStyledButton(
            text: "🎮 GAME CENTER",
            color: UIColor(red: 0.8, green: 0.3, blue: 1.0, alpha: 1.0),
            action: #selector(gameCenterTapped),
            fontSize: 18
        )
        view.addSubview(gameCenterButton)
        
        // Layout constraints
        let safeArea = view.safeAreaLayoutGuide
        let spacing: CGFloat = 12
        
        NSLayoutConstraint.activate([
            // Game Center status in top right
            gameCenterStatusLabel.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 8),
            gameCenterStatusLabel.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -15),
            gameCenterStatusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: safeArea.leadingAnchor, constant: 15),
            
            // Title at top (reduced margin for landscape)
            titleLabel.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 15),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            
            // Subtitle below title
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Buttons centered vertically with compact sizing
            startButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startButton.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -45),
            startButton.widthAnchor.constraint(equalToConstant: 220),
            startButton.heightAnchor.constraint(equalToConstant: 45),
            
            highScoreButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            highScoreButton.topAnchor.constraint(equalTo: startButton.bottomAnchor, constant: spacing),
            highScoreButton.widthAnchor.constraint(equalToConstant: 220),
            highScoreButton.heightAnchor.constraint(equalToConstant: 45),
            
            aboutButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            aboutButton.topAnchor.constraint(equalTo: highScoreButton.bottomAnchor, constant: spacing),
            aboutButton.widthAnchor.constraint(equalToConstant: 220),
            aboutButton.heightAnchor.constraint(equalToConstant: 45),
            
            gameCenterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            gameCenterButton.topAnchor.constraint(equalTo: aboutButton.bottomAnchor, constant: spacing),
            gameCenterButton.widthAnchor.constraint(equalToConstant: 220),
            gameCenterButton.heightAnchor.constraint(equalToConstant: 45)
        ])
        
        // Add pulsing animation to title
        animateTitle()
        
        // Set up notification observer for Game Center authentication
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(gameCenterAuthChanged),
            name: NSNotification.Name("GameCenterAuthenticationChanged"),
            object: nil
        )
        
        // Poll for status updates every 2 seconds while authenticating
        scheduleStatusUpdate()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateGameCenterStatus()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func scheduleStatusUpdate() {
        // Update status every 2 seconds for up to 10 seconds while authenticating
        var pollCount = 0
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            self.updateGameCenterStatus()
            pollCount += 1
            
            // Stop polling after 10 seconds or when authenticated
            if pollCount >= 5 || GameCenterManager.shared.isAuthenticated {
                timer.invalidate()
            }
        }
    }
    
    @objc private func gameCenterAuthChanged() {
        updateGameCenterStatus()
    }
    
    private func updateGameCenterStatus() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let label = self.gameCenterStatusLabel else { return }
            
            let statusMsg = GameCenterManager.shared.getStatusMessage()
            
            if GameCenterManager.shared.isAuthenticated {
                label.text = "🎮 ✓ \(statusMsg)"
                label.textColor = .green
            } else {
                #if targetEnvironment(simulator)
                label.text = "🎮 \(statusMsg)"
                label.textColor = .gray
                #else
                label.text = "🎮 \(statusMsg)"
                label.textColor = .orange
                #endif
            }
        }
    }
    
    private func setupAnimatedBackground() {
        // Create isometric grid pattern in background
        let gridLayer = CAShapeLayer()
        let path = CGMutablePath()
        
        let gridSize: CGFloat = 40
        for x in stride(from: -view.bounds.width, to: view.bounds.width * 2, by: gridSize) {
            for y in stride(from: -view.bounds.height, to: view.bounds.height * 2, by: gridSize) {
                // Draw isometric diamond
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x + gridSize/2, y: y - gridSize/4))
                path.addLine(to: CGPoint(x: x + gridSize, y: y))
                path.addLine(to: CGPoint(x: x + gridSize/2, y: y + gridSize/4))
                path.closeSubpath()
            }
        }
        
        gridLayer.path = path
        gridLayer.strokeColor = UIColor(red: 0.3, green: 0.3, blue: 0.4, alpha: 0.2).cgColor
        gridLayer.fillColor = UIColor.clear.cgColor
        gridLayer.lineWidth = 1
        view.layer.insertSublayer(gridLayer, at: 0)
    }
    
    private func createStyledButton(text: String, color: UIColor, action: Selector, fontSize: CGFloat = 22) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(text, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: fontSize)
        button.setTitleColor(color, for: .normal)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 3
        button.layer.borderColor = color.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: action, for: .touchUpInside)
        
        // Add glow effect
        button.layer.shadowColor = color.cgColor
        button.layer.shadowOffset = .zero
        button.layer.shadowRadius = 8
        button.layer.shadowOpacity = 0.6
        
        // Add touch feedback
        button.addTarget(self, action: #selector(buttonTouchDown), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchUp), for: [.touchUpInside, .touchUpOutside])
        
        return button
    }
    
    private func animateTitle() {
        UIView.animate(withDuration: 1.5, delay: 0, options: [.repeat, .autoreverse], animations: {
            self.titleLabel.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
        })
    }
    
    @objc private func buttonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            sender.alpha = 0.7
        }
    }
    
    @objc private func buttonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = .identity
            sender.alpha = 1.0
        }
    }
    
    @objc private func startGameTapped() {
        onStartGame?()
    }
    
    @objc private func highScoreTapped() {
        onShowLeaderboard?()
    }
    
    @objc private func aboutTapped() {
        onShowAbout?()
    }
    
    @objc private func gameCenterTapped() {
        if GameCenterManager.shared.isAuthenticated {
            GameCenterManager.shared.showGameCenterLeaderboard()
        } else {
            // Show alert if not authenticated
            #if targetEnvironment(simulator)
            let message = "Game Center is not available in the Simulator. Please test on a real iOS device with an Apple ID signed into Game Center."
            #else
            let message = "Game Center is not available. Please sign in to Game Center in Settings."
            #endif
            
            let alert = UIAlertController(
                title: "Game Center",
                message: message,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
}
