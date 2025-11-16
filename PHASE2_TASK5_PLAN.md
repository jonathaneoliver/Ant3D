# Phase 2 Task 5: Extract UI Managers

## Current State
- **GameViewController3D**: 907 lines
- **Location**: `AntAttack3D/ViewControllers/GameViewController3D.swift`
- **Target**: Reduce to ~300-400 lines by extracting HUD and UI management

## HUD Code Sections to Extract

### 1. Debug Label (lines ~175-203)
- setupBigDebugLabel()
- updateDebugLabel(_:)
- Property: debugLabel

### 2. Connection Status HUD (lines ~207-256)
- setupConnectionStatusHUD()
- updateConnectionStatus(_:serverURL:)
- Property: connectionStatusLabel

### 3. Ball Visibility HUD (lines ~258-305)
- setupVisibilityHUD()
- updateBallVisibility(_:)
- Property: visibilityLabel

### 4. Distance HUD (lines ~307-349)
- setupDistanceHUD()
- updateDistance(_:)
- Property: distanceLabel

### 5. Hostage Rescue HUD (lines ~351-426)
- setupHostageHUD()
- updateHostageCount(_:total:)
- showLevelCompleteMessage()
- Properties: hostageStackView, hostageFaces

### 6. Score HUD (lines ~428-466)
- setupScoreHUD()
- updateScore(_:)
- Property: scoreLabel

### 7. Level HUD (lines ~468-506)
- setupLevelHUD()
- updateLevel(_:)
- Property: levelLabel

### 8. Mini-Map HUD (lines ~508-626)
- setupMiniMap()
- updateMiniMap()
- Properties: miniMapView, miniMapDots, miniMapPlayerDot, miniMapSafeMatIndicator

### 9. Debug HUD Visibility (lines ~628-668)
- updateDebugHUDVisibility(_:)
- Controls which HUD elements are visible

### 10. Game Over UI (lines ~686-905)
- setupGameOverCallback()
- showGameOver()
- hideGameOver()
- continueGame()
- Properties: gameOverView, isPaused

## Proposed Solution: Create HUDManager

### File: `AntAttack3D/UI/HUDManager.swift`

```swift
import UIKit
import SceneKit

/// Manages all HUD elements in the game
class HUDManager {
    // MARK: - Properties
    
    weak var view: UIView?
    weak var gameScene: GameScene3D?
    
    // HUD Elements
    private var debugLabel: UILabel?
    private var connectionStatusLabel: UILabel?
    private var visibilityLabel: UILabel?
    private var distanceLabel: UILabel?
    private var hostageStackView: UIStackView?
    private var hostageFaces: [UILabel] = []
    private var scoreLabel: UILabel?
    private var levelLabel: UILabel?
    private var miniMapView: UIView?
    private var miniMapDots: [UIView] = []
    private var miniMapPlayerDot: UIView?
    private var miniMapSafeMatIndicator: UIView?
    private var gameOverView: UIView?
    
    // State
    private var isPaused: Bool = false
    
    // Callbacks
    var onContinueGame: (() -> Void)?
    var onReturnToTitle: (() -> Void)?
    
    // MARK: - Setup
    
    func setup() {
        guard let view = view else { return }
        
        setupDebugLabel()
        setupConnectionStatusHUD()
        setupVisibilityHUD()
        setupDistanceHUD()
        setupHostageHUD()
        setupScoreHUD()
        setupLevelHUD()
        setupMiniMap()
        
        // Default: hide debug HUDs
        updateDebugHUDVisibility(false)
    }
    
    func cleanup() {
        // Remove all HUD elements
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
    
    // MARK: - Update Methods
    
    func updateDebugLabel(_ message: String) { ... }
    func updateConnectionStatus(_ isConnected: Bool, serverURL: String) { ... }
    func updateBallVisibility(_ isVisible: Bool) { ... }
    func updateDistance(_ distance: Float) { ... }
    func updateHostageCount(_ saved: Int, _ total: Int) { ... }
    func updateScore(_ score: Int) { ... }
    func updateLevel(_ level: Int) { ... }
    func updateMiniMap() { ... }
    func updateDebugHUDVisibility(_ visible: Bool) { ... }
    
    // MARK: - Game Over
    
    func showGameOver() { ... }
    func hideGameOver() { ... }
    
    // MARK: - Level Complete
    
    func showLevelCompleteMessage() { ... }
}
```

## Refactored GameViewController3D

### After Extraction (target ~300-400 lines):

```swift
class GameViewController3D: UIViewController {
    
    var sceneView: SCNView!
    public var gameScene: GameScene3D!
    
    // Managers
    var inputManager: InputManager!
    var hudManager: HUDManager!
    
    deinit {
        inputManager?.cleanup()
        hudManager?.cleanup()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create scene view
        setupSceneView()
        
        // Create game scene
        gameScene = GameScene3D()
        sceneView.scene = gameScene
        
        // Setup managers
        setupManagers()
        
        // Setup callbacks
        setupCallbacks()
        
        // Start game loop
        startCameraUpdateLoop()
    }
    
    private func setupManagers() {
        // Input manager
        inputManager = InputManager()
        inputManager.gameScene = gameScene
        inputManager.viewController = self
        inputManager.setup()
        
        // HUD manager
        hudManager = HUDManager()
        hudManager.view = view
        hudManager.gameScene = gameScene
        hudManager.setup()
    }
    
    private func setupCallbacks() {
        // Config manager callbacks
        ConfigManager.shared.onConnectionStatusChanged = { [weak self] isConnected, serverURL in
            self?.hudManager.updateConnectionStatus(isConnected, serverURL: serverURL)
        }
        
        ConfigManager.shared.onConfigUpdate = { [weak self] config in
            self?.hudManager.updateDebugHUDVisibility(config.showDebugHUD)
            self?.sceneView.showsStatistics = config.showsStatistics
            self?.gameScene.onConfigReceived(config)
        }
        
        // Game scene callbacks
        gameScene.onBallVisibilityChanged = { [weak self] isVisible in
            self?.hudManager.updateBallVisibility(isVisible)
        }
        
        gameScene.onDistanceChanged = { [weak self] distance in
            self?.hudManager.updateDistance(distance)
        }
        
        gameScene.onHostageCountChanged = { [weak self] saved, total in
            self?.hudManager.updateHostageCount(saved, total)
        }
        
        gameScene.onScoreChanged = { [weak self] score in
            self?.hudManager.updateScore(score)
        }
        
        gameScene.onLevelComplete = { [weak self] newLevel in
            self?.hudManager.updateLevel(newLevel)
            self?.hudManager.showLevelCompleteMessage()
        }
        
        gameScene.onGameOver = { [weak self] in
            self?.hudManager.showGameOver()
        }
    }
}
```

## Implementation Steps

1. **Create `UI/HUDManager.swift`** (~400-500 lines)
   - Copy all setup methods from GameViewController3D
   - Copy all update methods
   - Copy game over UI code
   - Add cleanup method

2. **Refactor GameViewController3D**
   - Remove all HUD properties (~13 properties)
   - Remove all HUD setup methods (~9 methods)
   - Remove all HUD update methods (~9 methods)
   - Remove game over UI code (~200 lines)
   - Add HUDManager property
   - Update viewDidLoad to use HUDManager
   - Update callbacks to route through HUDManager

3. **Add HUDManager to Xcode project**
   - Use `add_files_to_xcode.py` script
   - Add to UI group

4. **Build and test**
   - Verify all HUD elements work
   - Verify game over screen works
   - Verify mini-map works

## Expected Results

- **GameViewController3D**: 907 → ~350 lines (-557 lines, -61% reduction)
- **HUDManager.swift**: ~500 lines (new file)
- **Total codebase**: More maintainable, better separation of concerns
- **Phase 2 complete**: All refactoring goals achieved

## Estimated Time

- Implementation: 2-3 hours
- Testing: 30 minutes
- **Total**: 2.5-3.5 hours

## Next Steps

After completing Phase 2 Task 5:
1. Commit and push changes
2. Create summary document of Phase 2 achievements
3. Consider Phase 3 (additional features/polish) or conclude refactoring

---

**Status**: 🟡 Ready to implement
**Priority**: Medium (improves maintainability but not critical)
**Complexity**: Medium (large code extraction but straightforward)
