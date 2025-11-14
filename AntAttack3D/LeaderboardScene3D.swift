import UIKit
import GameKit

class LeaderboardScene3D: UIViewController, UITextFieldDelegate {
    var onBack: (() -> Void)?
    private var finalScore: Int = 0
    private var initials: String = ""
    private var promptLabel: UILabel!
    private var initialsLabel: UILabel!
    private var scores: [(String, Int, String)] = [] // (initials, score, date)
    private let maxScores = 10
    private var viewOnly: Bool { finalScore < 0 }
    private var backButton: UIButton!
    private var gameCenterButton: UIButton!
    private var initialsField: UITextField?
    private var scoreLabelsContainer: UIStackView!
    private var statusLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Dark background
        view.backgroundColor = .black
        
        // Load scores first to determine if user qualifies
        loadScores()
        
        let qualifies: Bool = {
            if finalScore < 0 { return false }
            if scores.count < maxScores { return true }
            return finalScore > scores.last?.1 ?? Int.min
        }()
        
        let isEntry = qualifies
        let isViewOnly = !isEntry
        let safeArea = view.safeAreaLayoutGuide
        
        // Prompt/Title label
        promptLabel = UILabel()
        if isViewOnly {
            promptLabel.text = "HIGH SCORES"
        } else {
            promptLabel.text = "NEW HIGH SCORE!\nEnter your initials:"
        }
        promptLabel.font = UIFont.boldSystemFont(ofSize: isViewOnly ? 48 : 32)
        promptLabel.textColor = isViewOnly ? .cyan : .yellow
        promptLabel.textAlignment = .center
        promptLabel.numberOfLines = 0
        promptLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(promptLabel)
        
        // Initials label (for visual feedback)
        initialsLabel = UILabel()
        initialsLabel.text = isViewOnly ? "" : "___"
        initialsLabel.font = UIFont.boldSystemFont(ofSize: 48)
        initialsLabel.textColor = .yellow
        initialsLabel.textAlignment = .center
        initialsLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(initialsLabel)
        
        // GameCenter status indicator
        statusLabel = UILabel()
        if GameCenterManager.shared.isAuthenticated {
            statusLabel.text = "🎮 GameCenter Connected"
            statusLabel.textColor = .green
        } else {
            statusLabel.text = "🎮 GameCenter Offline"
            statusLabel.textColor = .orange
        }
        statusLabel.font = UIFont.boldSystemFont(ofSize: 24)
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        
        // Score labels container
        scoreLabelsContainer = UIStackView()
        scoreLabelsContainer.axis = .vertical
        scoreLabelsContainer.alignment = .leading
        scoreLabelsContainer.spacing = 8
        scoreLabelsContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scoreLabelsContainer)
        
        // Buttons
        if isViewOnly {
            // Back button
            backButton = UIButton(type: .system)
            backButton.setTitle("BACK", for: .normal)
            backButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 32)
            backButton.setTitleColor(.green, for: .normal)
            backButton.backgroundColor = UIColor(red: 0, green: 0.3, blue: 0, alpha: 0.6)
            backButton.layer.cornerRadius = 10
            backButton.layer.borderWidth = 2
            backButton.layer.borderColor = UIColor.green.cgColor
            backButton.translatesAutoresizingMaskIntoConstraints = false
            backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
            view.addSubview(backButton)
            
            // GameCenter button (if authenticated)
            if GameCenterManager.shared.isAuthenticated {
                gameCenterButton = UIButton(type: .system)
                gameCenterButton.setTitle("🎮 FULL LEADERBOARD", for: .normal)
                gameCenterButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 28)
                gameCenterButton.setTitleColor(.cyan, for: .normal)
                gameCenterButton.backgroundColor = UIColor(red: 0, green: 0.3, blue: 0.5, alpha: 0.6)
                gameCenterButton.layer.cornerRadius = 10
                gameCenterButton.layer.borderWidth = 2
                gameCenterButton.layer.borderColor = UIColor.cyan.cgColor
                gameCenterButton.translatesAutoresizingMaskIntoConstraints = false
                gameCenterButton.addTarget(self, action: #selector(gameCenterTapped), for: .touchUpInside)
                view.addSubview(gameCenterButton)
            }
        }
        
        // Layout
        var constraints: [NSLayoutConstraint] = [
            promptLabel.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 30),
            promptLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            promptLabel.leadingAnchor.constraint(greaterThanOrEqualTo: safeArea.leadingAnchor, constant: 20),
            promptLabel.trailingAnchor.constraint(lessThanOrEqualTo: safeArea.trailingAnchor, constant: -20),
            
            initialsLabel.topAnchor.constraint(equalTo: promptLabel.bottomAnchor, constant: 20),
            initialsLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            statusLabel.topAnchor.constraint(equalTo: initialsLabel.bottomAnchor, constant: isViewOnly ? 20 : 40),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            scoreLabelsContainer.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 20),
            scoreLabelsContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scoreLabelsContainer.leadingAnchor.constraint(greaterThanOrEqualTo: safeArea.leadingAnchor, constant: 40),
            scoreLabelsContainer.trailingAnchor.constraint(lessThanOrEqualTo: safeArea.trailingAnchor, constant: -40)
        ]
        
        if isViewOnly {
            constraints.append(contentsOf: [
                backButton.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -20),
                backButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                backButton.widthAnchor.constraint(equalToConstant: 180),
                backButton.heightAnchor.constraint(equalToConstant: 60)
            ])
            
            if gameCenterButton != nil {
                constraints.append(contentsOf: [
                    gameCenterButton.bottomAnchor.constraint(equalTo: backButton.topAnchor, constant: -15),
                    gameCenterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                    gameCenterButton.widthAnchor.constraint(equalToConstant: 300),
                    gameCenterButton.heightAnchor.constraint(equalToConstant: 60)
                ])
            }
        }
        
        NSLayoutConstraint.activate(constraints)
        
        showLeaderboard()
        
        if isEntry {
            showInitialsKeyboard()
        }
    }
    
    private func showInitialsKeyboard() {
        let field = UITextField(frame: CGRect(x: view.frame.width/2 - 100, y: view.frame.height/2 - 30, width: 200, height: 60))
        field.placeholder = "Enter initials"
        field.textAlignment = .center
        field.autocapitalizationType = .allCharacters
        field.autocorrectionType = .no
        field.returnKeyType = .done
        field.keyboardType = .asciiCapable
        field.delegate = self
        field.textColor = .black
        field.backgroundColor = .white
        field.font = UIFont.boldSystemFont(ofSize: 32)
        field.layer.cornerRadius = 10
        field.layer.masksToBounds = true
        field.becomeFirstResponder()
        view.addSubview(field)
        initialsField = field
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = textField.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        let allowed = updatedText.uppercased().filter { $0.isLetter }
        if allowed.count > 3 { return false }
        initialsLabel.text = allowed + String(repeating: "_", count: 3 - allowed.count)
        return allowed.count <= 3
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        let entered = (textField.text ?? "").uppercased().filter { $0.isLetter }
        if entered.count >= 1 && entered.count <= 3 {
            initials = entered + String(repeating: "_", count: max(0, 3 - entered.count))
            textField.resignFirstResponder()
            initialsField?.removeFromSuperview()
            initialsField = nil
            saveScore()
            showLeaderboard()
            promptLabel.text = "Score Saved!\nTap Back to return"
            return true
        } else if entered.isEmpty {
            textField.resignFirstResponder()
            return true
        }
        return true
    }
    
    func setFinalScore(_ score: Int) {
        finalScore = score
    }
    
    @objc private func backTapped() {
        onBack?()
    }
    
    @objc private func gameCenterTapped() {
        GameCenterManager.shared.showGameCenterLeaderboard()
    }
    
    private func saveScore() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: Date())
        scores.append((initials, finalScore, dateStr))
        scores.sort { $0.1 > $1.1 }
        if scores.count > maxScores { scores = Array(scores.prefix(maxScores)) }
        let scoresData = scores.map { [$0.0, String($0.1), $0.2] }
        UserDefaults.standard.set(scoresData, forKey: "leaderboard")
        
        // Submit to Game Center
        GameCenterManager.shared.submitScore(finalScore)
    }
    
    private func loadScores() {
        scores.removeAll()
        
        // Load from UserDefaults first (synchronous)
        if let scoresData = UserDefaults.standard.array(forKey: "leaderboard") as? [[String]] {
            for entry in scoresData {
                if entry.count == 3, let score = Int(entry[1]) {
                    scores.append((entry[0], score, entry[2]))
                }
            }
        }
        
        // If no local scores, add placeholder
        if scores.isEmpty {
            scores.append(("No scores yet", 0, "Play to compete!"))
        }
        
        // Then try to load Game Center scores asynchronously (if authenticated)
        if GameCenterManager.shared.isAuthenticated {
            GameCenterManager.shared.loadLeaderboard { [weak self] gameCenterScores in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    self.scores.removeAll()
                    
                    if let gameCenterScores = gameCenterScores {
                        for score in gameCenterScores.prefix(self.maxScores) {
                            let playerName = score.player.displayName
                            let scoreValue = Int(score.value)
                            let date = DateFormatter.localizedString(from: score.date, dateStyle: .short, timeStyle: .none)
                            self.scores.append((playerName, scoreValue, date))
                        }
                    } else {
                        self.scores.append(("GameCenter", 0, "Unavailable"))
                    }
                    
                    // Only update display if UI is ready
                    if self.scoreLabelsContainer != nil {
                        self.showLeaderboard()
                    }
                }
            }
        }
    }
    
    private func showLeaderboard() {
        // Clear existing score labels
        scoreLabelsContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add score entries
        for (i, entry) in scores.prefix(maxScores).enumerated() {
            let entryLabel = UILabel()
            
            if entry.1 == 0 && (entry.0.contains("GameCenter") || entry.0.contains("No scores")) {
                entryLabel.text = entry.0
                entryLabel.textColor = .gray
            } else {
                // Use monospaced font for proper alignment
                entryLabel.font = UIFont.monospacedSystemFont(ofSize: 24, weight: .bold)
                entryLabel.text = String(format: "%2d. %-12s %,6d pts %s", i+1, entry.0, entry.1, entry.2)
                entryLabel.textColor = i == 0 ? UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) : .white
            }
            
            entryLabel.font = UIFont.monospacedSystemFont(ofSize: 24, weight: .bold)
            entryLabel.numberOfLines = 1
            entryLabel.adjustsFontSizeToFitWidth = true
            entryLabel.minimumScaleFactor = 0.5
            
            scoreLabelsContainer.addArrangedSubview(entryLabel)
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
}
