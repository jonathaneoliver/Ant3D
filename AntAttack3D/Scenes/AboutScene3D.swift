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
        
        // Back button - positioned in top right corner
        backButton = UIButton(type: .system)
        backButton.setTitle("◀ BACK", for: .normal)
        backButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 20)
        backButton.setTitleColor(UIColor(red: 0, green: 1, blue: 0, alpha: 1), for: .normal)
        backButton.backgroundColor = UIColor(red: 0, green: 0.3, blue: 0, alpha: 0.8)
        backButton.layer.cornerRadius = 8
        backButton.layer.borderWidth = 2
        backButton.layer.borderColor = UIColor(red: 0, green: 0.8, blue: 0, alpha: 0.8).cgColor
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        view.addSubview(backButton)
        
        // Title label - smaller for landscape
        let titleLabel = UILabel()
        titleLabel.text = "HOW TO PLAY"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textColor = UIColor(red: 1, green: 1, blue: 0, alpha: 1)
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
        
        // Instructions text - smaller fonts for landscape
        let instructions: [(String, UIColor, UIFont, Bool)] = [
            ("OBJECTIVE:", UIColor(red: 0, green: 1, blue: 1, alpha: 1), UIFont.boldSystemFont(ofSize: 16), false),
            ("Rescue all hostages and bring them to the safe mat!", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 12), false),
            ("", .clear, UIFont.systemFont(ofSize: 4), false),
            
            ("CONTROLS:", UIColor(red: 0, green: 1, blue: 1, alpha: 1), UIFont.boldSystemFont(ofSize: 16), false),
            ("• Xbox Controller: Left stick to move", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 12), false),
            ("• A Button: Hold to climb walls", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 12), false),
            ("• B Button: Rotate camera 45°", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 12), false),
            ("• X Button: Exit game", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 12), false),
            ("", .clear, UIFont.systemFont(ofSize: 4), false),
            
            ("GAMEPLAY:", UIColor(red: 0, green: 1, blue: 1, alpha: 1), UIFont.boldSystemFont(ofSize: 16), false),
            ("• Navigate the isometric 3D city", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 12), false),
            ("• Find hostages (blue figures) on raised platforms", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 12), false),
            ("• Get close to rescue them - they'll follow you!", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 12), false),
            ("• Lead them back to the safe mat (your start position)", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 12), false),
            ("• Avoid red enemy balls patrolling the city!", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 12), false),
            ("", .clear, UIFont.systemFont(ofSize: 4), false),
            
            ("WALL CLIMBING:", UIColor(red: 0, green: 1, blue: 1, alpha: 1), UIFont.boldSystemFont(ofSize: 16), false),
            ("• Hold A button while moving into a wall", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 12), false),
            ("• You'll climb straight up", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 12), false),
            ("• Release A at the top to transition to horizontal", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 12), false),
            ("• Look for ramps to make climbing easier!", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 12), false),
            ("", .clear, UIFont.systemFont(ofSize: 4), false),
            
            ("SCORING:", UIColor(red: 0, green: 1, blue: 1, alpha: 1), UIFont.boldSystemFont(ofSize: 16), false),
            ("• +1000 points for each hostage saved", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 12), false),
            ("• Complete levels to increase difficulty", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 12), false),
            ("• More hostages and enemies each level!", UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), UIFont.systemFont(ofSize: 12), false),
            ("", .clear, UIFont.systemFont(ofSize: 4), false),
            
            ("TIP: Use the mini-map (bottom-right) to find hostages!", UIColor(red: 1, green: 0.8, blue: 0, alpha: 1), UIFont.boldSystemFont(ofSize: 13), true)
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
                label.layer.cornerRadius = 6
                label.layer.backgroundColor = UIColor(red: 1, green: 0.6, blue: 0, alpha: 0.2).cgColor
                label.layer.borderWidth = 2
                label.layer.borderColor = UIColor(red: 1, green: 0.8, blue: 0, alpha: 0.6).cgColor
                label.textAlignment = .center
            }
            
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
                label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15)
            ])
            
            if let previous = previousLabel {
                let spacing: CGFloat = text.isEmpty ? 8 : (text.hasSuffix(":") ? 10 : 6)
                label.topAnchor.constraint(equalTo: previous.bottomAnchor, constant: spacing).isActive = true
            } else {
                label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 15).isActive = true
            }
            
            previousLabel = label
        }
        
        // Content view height
        if let lastLabel = previousLabel {
            contentView.bottomAnchor.constraint(equalTo: lastLabel.bottomAnchor, constant: 15).isActive = true
        }
        
        // Layout constraints - landscape optimized
        NSLayoutConstraint.activate([
            // Back button in top right corner
            backButton.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 10),
            backButton.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -10),
            backButton.widthAnchor.constraint(equalToConstant: 100),
            backButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Title next to back button
            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Scroll view takes most of the space
            scrollView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 15),
            scrollView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -15),
            scrollView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -10),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
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
