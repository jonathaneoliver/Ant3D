import UIKit

class AboutScene3D: UIViewController {
    var onBack: (() -> Void)?
    
    private var backButton: UIButton!
    private var scrollView: UIScrollView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Dark background matching title screen
        view.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        
        let safeArea = view.safeAreaLayoutGuide
        
        // Title label
        let titleLabel = UILabel()
        titleLabel.text = "HOW TO PLAY"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 36)
        titleLabel.textColor = UIColor(red: 1, green: 1, blue: 0, alpha: 1) // Bright yellow
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // Scroll view for instructions
        scrollView = UIScrollView()
        scrollView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.4)
        scrollView.layer.cornerRadius = 10
        scrollView.layer.borderWidth = 1
        scrollView.layer.borderColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 0.8).cgColor
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        // Content container
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        // Instructions text
        let instructions: [(String, UIColor, UIFont, Bool)] = [
            ("OBJECTIVE:", UIColor(red: 0, green: 1, blue: 1, alpha: 1), UIFont.boldSystemFont(ofSize: 20), false),
            ("Rescue all hostages and bring them to the safe mat!", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 14), false),
            ("", .clear, UIFont.systemFont(ofSize: 8), false),
            
            ("CONTROLS:", UIColor(red: 0, green: 1, blue: 1, alpha: 1), UIFont.boldSystemFont(ofSize: 20), false),
            ("• Xbox Controller: Left stick to move", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 14), false),
            ("• A Button: Hold to climb walls", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 14), false),
            ("• B Button: Rotate camera 45°", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 14), false),
            ("• X Button: Exit game", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 14), false),
            ("", .clear, UIFont.systemFont(ofSize: 8), false),
            
            ("GAMEPLAY:", UIColor(red: 0, green: 1, blue: 1, alpha: 1), UIFont.boldSystemFont(ofSize: 20), false),
            ("• Navigate the isometric 3D city", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 14), false),
            ("• Find hostages (blue figures) on raised platforms", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 14), false),
            ("• Get close to rescue them - they'll follow you!", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 14), false),
            ("• Lead them back to the safe mat (your start position)", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 14), false),
            ("• Avoid red enemy balls patrolling the city!", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 14), false),
            ("", .clear, UIFont.systemFont(ofSize: 8), false),
            
            ("WALL CLIMBING:", UIColor(red: 0, green: 1, blue: 1, alpha: 1), UIFont.boldSystemFont(ofSize: 20), false),
            ("• Hold A button while moving into a wall", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 14), false),
            ("• You'll climb straight up", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 14), false),
            ("• Release A at the top to transition to horizontal", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 14), false),
            ("• Look for ramps to make climbing easier!", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 14), false),
            ("", .clear, UIFont.systemFont(ofSize: 8), false),
            
            ("SCORING:", UIColor(red: 0, green: 1, blue: 1, alpha: 1), UIFont.boldSystemFont(ofSize: 20), false),
            ("• +1000 points for each hostage saved", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 14), false),
            ("• Complete levels to increase difficulty", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 14), false),
            ("• More hostages and enemies each level!", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 14), false),
            ("", .clear, UIFont.systemFont(ofSize: 8), false),
            
            ("TIP: Use the mini-map (bottom-right) to find hostages!", UIColor(red: 1, green: 0.8, blue: 0, alpha: 1), UIFont.boldSystemFont(ofSize: 16), true)
        ]
        
        var previousLabel: UILabel? = nil
        for (text, color, font, isTip) in instructions {
            let label = UILabel()
            label.text = text
            label.font = font
            label.textColor = color
            label.numberOfLines = 0
            label.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(label)
            
            // Apply special styling for tip
            if isTip {
                label.layer.cornerRadius = 8
                label.layer.backgroundColor = UIColor(red: 1, green: 0.6, blue: 0, alpha: 0.2).cgColor
                label.layer.borderWidth = 2
                label.layer.borderColor = UIColor(red: 1, green: 0.8, blue: 0, alpha: 0.6).cgColor
                label.textAlignment = .center
            }
            
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
                label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
            ])
            
            if let previous = previousLabel {
                let spacing: CGFloat = text.isEmpty ? 12 : (text.hasSuffix(":") ? 15 : 10)
                label.topAnchor.constraint(equalTo: previous.bottomAnchor, constant: spacing).isActive = true
            } else {
                label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20).isActive = true
            }
            
            previousLabel = label
        }
        
        // Content view height
        if let lastLabel = previousLabel {
            contentView.bottomAnchor.constraint(equalTo: lastLabel.bottomAnchor, constant: 20).isActive = true
        }
        
        // Back button
        backButton = UIButton(type: .system)
        backButton.setTitle("← BACK", for: .normal)
        backButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 28)
        backButton.setTitleColor(UIColor(red: 0, green: 1, blue: 0, alpha: 1), for: .normal)
        backButton.backgroundColor = UIColor(red: 0, green: 0.3, blue: 0, alpha: 0.6)
        backButton.layer.cornerRadius = 10
        backButton.layer.borderWidth = 2
        backButton.layer.borderColor = UIColor(red: 0, green: 0.8, blue: 0, alpha: 0.8).cgColor
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        view.addSubview(backButton)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Title
            titleLabel.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 15),
            scrollView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -15),
            scrollView.bottomAnchor.constraint(equalTo: backButton.topAnchor, constant: -15),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Back button
            backButton.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -20),
            backButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 150),
            backButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    @objc private func backTapped() {
        onBack?()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
}
