import UIKit

class TitleScene3D: UIViewController {
    var onStartGame: (() -> Void)?
    var onShowLeaderboard: (() -> Void)?
    var onShowAbout: (() -> Void)?
    
    private var titleLabel: UILabel!
    private var startButton: UIButton!
    private var highScoreButton: UIButton!
    private var aboutButton: UIButton!
    private var gameCenterButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Dark gradient background (Ant Attack style)
        view.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
        
        // Add subtle animated background
        setupAnimatedBackground()
        
        // Title label
        titleLabel = UILabel()
        titleLabel.text = "ANT ATTACK 3D"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 48)
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
        subtitleLabel.font = UIFont.systemFont(ofSize: 20)
        subtitleLabel.textColor = UIColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 1.0) // Cyan
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)
        
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
            fontSize: 22
        )
        view.addSubview(gameCenterButton)
        
        // Layout constraints
        let safeArea = view.safeAreaLayoutGuide
        let spacing: CGFloat = 20
        
        NSLayoutConstraint.activate([
            // Title at top
            titleLabel.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 80),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            
            // Subtitle below title
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Buttons centered vertically
            startButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startButton.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),
            startButton.widthAnchor.constraint(equalToConstant: 280),
            startButton.heightAnchor.constraint(equalToConstant: 60),
            
            highScoreButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            highScoreButton.topAnchor.constraint(equalTo: startButton.bottomAnchor, constant: spacing),
            highScoreButton.widthAnchor.constraint(equalToConstant: 280),
            highScoreButton.heightAnchor.constraint(equalToConstant: 60),
            
            aboutButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            aboutButton.topAnchor.constraint(equalTo: highScoreButton.bottomAnchor, constant: spacing),
            aboutButton.widthAnchor.constraint(equalToConstant: 280),
            aboutButton.heightAnchor.constraint(equalToConstant: 60),
            
            gameCenterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            gameCenterButton.topAnchor.constraint(equalTo: aboutButton.bottomAnchor, constant: spacing),
            gameCenterButton.widthAnchor.constraint(equalToConstant: 280),
            gameCenterButton.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        // Add pulsing animation to title
        animateTitle()
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
    
    private func createStyledButton(text: String, color: UIColor, action: Selector, fontSize: CGFloat = 28) -> UIButton {
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
        GameCenterManager.shared.showGameCenterLeaderboard()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
}
