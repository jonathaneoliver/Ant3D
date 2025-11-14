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
        
        let isEntry = (finalScore >= 0)
        let isViewOnly = !isEntry
        let safeArea = view.safeAreaLayoutGuide
        
        // Prompt/Title label - smaller for landscape
        promptLabel = UILabel()
        if isViewOnly {
            promptLabel.text = "HIGH SCORES"
        } else {
            promptLabel.text = "NEW HIGH SCORE!\nEnter your initials:"
        }
        promptLabel.font = UIFont.boldSystemFont(ofSize: isViewOnly ? 28 : 24)
        promptLabel.textColor = isViewOnly ? .cyan : .yellow
        promptLabel.textAlignment = .center
        promptLabel.numberOfLines = 0
        promptLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(promptLabel)
        
        // Initials label (for visual feedback) - smaller
        initialsLabel = UILabel()
        initialsLabel.text = isViewOnly ? "" : "___"
        initialsLabel.font = UIFont.boldSystemFont(ofSize: 32)
        initialsLabel.textColor = .yellow
        initialsLabel.textAlignment = .center
        initialsLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(initialsLabel)
        
        // GameCenter status indicator - smaller
        statusLabel = UILabel()
        if GameCenterManager.shared.isAuthenticated {
            statusLabel.text = "🎮 Connected"
            statusLabel.textColor = .green
        } else {
            statusLabel.text = "🎮 Offline"
            statusLabel.textColor = .orange
        }
        statusLabel.font = UIFont.boldSystemFont(ofSize: 14)
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        
        // Score labels container - in a scroll view for landscape
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        view.addSubview(scrollView)
        
        scoreLabelsContainer = UIStackView()
        scoreLabelsContainer.axis = .vertical
        scoreLabelsContainer.alignment = .leading
        scoreLabelsContainer.spacing = 6
        scoreLabelsContainer.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(scoreLabelsContainer)
        
        // Buttons - always create them
        // Back button - positioned in top right
        backButton = UIButton(type: .system)
        backButton.setTitle("◀ BACK", for: .normal)
        backButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 20)
        backButton.setTitleColor(.green, for: .normal)
        backButton.backgroundColor = UIColor(red: 0, green: 0.3, blue: 0, alpha: 0.8)
        backButton.layer.cornerRadius = 8
        backButton.layer.borderWidth = 2
        backButton.layer.borderColor = UIColor.green.cgColor
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        backButton.isHidden = !isViewOnly  // Hidden during score entry
        view.addSubview(backButton)
        
        // GameCenter button (if authenticated) - positioned in top left
        if GameCenterManager.shared.isAuthenticated {
            gameCenterButton = UIButton(type: .system)
            gameCenterButton.setTitle("🎮", for: .normal)
            gameCenterButton.titleLabel?.font = UIFont.systemFont(ofSize: 28)
            gameCenterButton.backgroundColor = UIColor(red: 0, green: 0.3, blue: 0.5, alpha: 0.8)
            gameCenterButton.layer.cornerRadius = 8
            gameCenterButton.layer.borderWidth = 2
            gameCenterButton.layer.borderColor = UIColor.cyan.cgColor
            gameCenterButton.translatesAutoresizingMaskIntoConstraints = false
            gameCenterButton.addTarget(self, action: #selector(gameCenterTapped), for: .touchUpInside)
            gameCenterButton.isHidden = !isViewOnly  // Hidden during score entry
            view.addSubview(gameCenterButton)
        }
        
        // Layout constraints - optimized for landscape
        var constraints: [NSLayoutConstraint] = [
            // Title at top, compact spacing
            promptLabel.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 10),
            promptLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            promptLabel.leadingAnchor.constraint(greaterThanOrEqualTo: safeArea.leadingAnchor, constant: 120),
            promptLabel.trailingAnchor.constraint(lessThanOrEqualTo: safeArea.trailingAnchor, constant: -120),
            
            // Initials below title
            initialsLabel.topAnchor.constraint(equalTo: promptLabel.bottomAnchor, constant: 5),
            initialsLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Status below initials
            statusLabel.topAnchor.constraint(equalTo: initialsLabel.bottomAnchor, constant: isViewOnly ? 5 : 10),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // ScrollView for scores - takes remaining space
            scrollView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -10),
            
            // Score container inside scroll view
            scoreLabelsContainer.topAnchor.constraint(equalTo: scrollView.topAnchor),
            scoreLabelsContainer.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            scoreLabelsContainer.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            scoreLabelsContainer.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            scoreLabelsContainer.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ]
        
        // Button constraints - always add them since buttons are always created
        constraints.append(contentsOf: [
            // Back button in top right corner
            backButton.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 10),
            backButton.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -10),
            backButton.widthAnchor.constraint(equalToConstant: 100),
            backButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        if gameCenterButton != nil {
            constraints.append(contentsOf: [
                // GameCenter button in top left corner
                gameCenterButton.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 10),
                gameCenterButton.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 10),
                gameCenterButton.widthAnchor.constraint(equalToConstant: 50),
                gameCenterButton.heightAnchor.constraint(equalToConstant: 40)
            ])
        }
        
        NSLayoutConstraint.activate(constraints)
        
        // Load scores AFTER UI is fully set up
        loadScores()
        
        if isEntry {
            showInitialsKeyboard()
        }
    }

    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Display leaderboard when view is about to appear (safer than viewDidLoad)
        showLeaderboard()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Cancel any pending updates when view disappears
        print("🏆 LeaderboardScene3D: viewDidDisappear - view is no longer visible")
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
        
        // Safely update initialsLabel
        guard let initialsLabel = initialsLabel else {
            print("⚠️ initialsLabel is nil in textField delegate")
            return false
        }
        
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
            
            // Show the back button now that score is saved
            backButton?.isHidden = false
            gameCenterButton?.isHidden = false
            
            // Safely update promptLabel
            if let promptLabel = promptLabel {
                promptLabel.text = "Score Saved!\nTap Back to return"
            } else {
                print("⚠️ promptLabel is nil in textFieldShouldReturn")
            }
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
                    guard let self = self else {
                        print("⚠️ LeaderboardScene3D: self is nil in GameCenter callback")
                        return
                    }
                    
                    // Check if view is still loaded
                    guard self.isViewLoaded else {
                        print("⚠️ LeaderboardScene3D: view not loaded in GameCenter callback")
                        return
                    }
                    
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
                    
                    // Only update display if UI is ready and view is in window
                    if self.scoreLabelsContainer != nil && self.view.window != nil {
                        self.showLeaderboard()
                    } else {
                        print("⚠️ LeaderboardScene3D: Cannot update UI - scoreLabelsContainer=\(self.scoreLabelsContainer != nil), inWindow=\(self.view.window != nil)")
                    }
                }
            }
        }
    }
    
    private func showLeaderboard() {
        // Ensure we're on main thread
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.showLeaderboard()
            }
            return
        }
        
        // Guard against nil scoreLabelsContainer
        guard let scoreLabelsContainer = scoreLabelsContainer else {
            print("⚠️ scoreLabelsContainer is nil in showLeaderboard()")
            return
        }
        
        // Guard against view not being in window hierarchy
        guard view.window != nil else {
            print("⚠️ view not in window hierarchy in showLeaderboard()")
            return
        }
        
        // Clear existing score labels safely
        for subview in scoreLabelsContainer.arrangedSubviews {
            scoreLabelsContainer.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        
        // Add score entries
        for (i, entry) in scores.prefix(maxScores).enumerated() {
            let entryLabel = UILabel()
            
            if entry.1 == 0 && (entry.0.contains("GameCenter") || entry.0.contains("No scores")) {
                entryLabel.text = entry.0
                entryLabel.textColor = .gray
                entryLabel.font = UIFont.monospacedSystemFont(ofSize: 18, weight: .bold)
            } else {
                // Use monospaced font for proper alignment
                entryLabel.font = UIFont.monospacedSystemFont(ofSize: 18, weight: .bold)
                
                // Safely format the string without C-style format specifiers
                let rank = String(format: "%2d", i + 1)
                let name = entry.0.padding(toLength: 12, withPad: " ", startingAt: 0)
                let score = String(format: "%,6d", entry.1)
                let date = entry.2
                
                entryLabel.text = "\(rank). \(name) \(score) pts \(date)"
                entryLabel.textColor = i == 0 ? UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) : .white
            }
            
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
