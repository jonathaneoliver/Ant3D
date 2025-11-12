# Copilot Instructions for Asteroids Clone

## Project Overview
iOS SpriteKit game implementing classic Asteroids arcade gameplay. Built with Swift 5.7+, targeting iOS 15.0+. Uses scene-based architecture with real-time configuration, Game Center integration, and hardware controller support.

## Critical Architecture Patterns

### Scene Management & State Flow
- **Scene hierarchy**: MenuScene → GameScene/HelpScene/HighScoreScene/LevelCompleteScene → GameOverScene → MenuScene
- **Scene initialization**: All scenes use `init(size:)` - GameScene has optional `demoMode` parameter for AI-controlled demo
- **Accessibility setup**: Every scene sets `self.view?.accessibilityIdentifier` in `didMove(to:)` for UI testing
- **Scene transitions**: Use `SKTransition.fade(withDuration: 0.5)` then `view?.presentScene(newScene, transition: transition)`

### Configuration System (Hot-Reload)
- **ConfigManager.shared**: Singleton that polls HTTP server every 2 seconds for live config updates
- **Usage pattern**: Access via computed property `private var config: GameConfig { ConfigManager.shared.config }`
- **Observable changes**: Scenes observe config with `configCancellable = ConfigManager.shared.$config.sink { [weak self] _ in ... }`
- **Server**: Python Flask server in `ConfigServer/` serves `game_config.json` at port 8888
- **Hot-reload workflow**: Edit `game_config.json` → ConfigManager auto-detects → scenes update immediately without restart

### Input Architecture
- **PlayerInputManager**: Separate class handles ALL input (touch, controller, demo AI) - instantiated in GameScene.didMove
- **Touch controls**: VirtualJoystick (bottom-left) for rotation/thrust, FireButton (bottom-right), ShieldButton
- **Game Controller**: Full MFi controller support via GameController framework - discovered via NotificationCenter
- **Demo mode**: `isDemoMode` flag enables AI that targets nearest asteroid with angle-based rotation logic
- **Input pattern**: `playerInputManager.setupControls()` then `playerInputManager.setupGameController()` - controls hidden in demo mode

### Physics & Collision Detection
- **PhysicsCategory.swift**: Defines bitmask constants (spaceship=0b1, asteroid=0b10, bullet=0b100, shield=0b1000)
- **Contact handling**: GameScene implements `SKPhysicsContactDelegate` - check `bodyA.categoryBitMask` patterns
- **Screen wrapping**: All entities wrap via `wrapAroundScreen(for:)` - crucial for gameplay feel
- **Performance**: Physics bodies use `.dynamic` for moving objects, contact/collision masks minimize checks

### Game Center Integration
- **GameCenterManager.shared**: Singleton handles authentication and leaderboard submission
- **Authentication flow**: Called ONCE in SceneDelegate.sceneDidBecomeActive() to avoid duplicate prompts
- **Leaderboard ID**: Hardcoded as `"highscores.asteroids.jeoliver.com"` - change in GameCenterManager
- **Status indicators**: Scenes show Game Center auth status via NotificationCenter observer pattern
- **Score submission**: `GameCenterManager.shared.submitScore(score)` after game over

### Sound Management
- **SoundManager.shared**: Singleton manages all audio with caching for instant playback
- **Preloading**: MenuScene calls `preloadSounds(scene:completion:)` on startup to prevent first-fire lag
- **Scene-aware**: Use `setGameSceneActive(true/false)` to prevent menu sounds during gameplay
- **Audio files**: .wav files stored directly in AsteroidsClone/ folder (not Resources/ - that's for textures)
- **Volume control**: ConfigManager provides volume settings - SoundManager respects these

### Entity Patterns
- **Base class**: All game objects inherit from SKNode, not SKSpriteNode
- **Spaceship**: Uses SKShapeNode for vector graphics, separate thrustNode for flame effect
- **Asteroids**: Three sizes (large/medium/small) with `breakApart()` method spawning smaller asteroids
- **Bullets**: Lifetime-managed via `SKAction.sequence` - auto-remove after duration
- **Node naming**: SKNodes use `.name` property for identification (NOT `.accessibilityIdentifier` - that's UIKit-only)

## Build & Test Commands

### Standard Build
```bash
# Build for simulator (iPhone 17 preferred for iOS 26.1 testing)
xcodebuild -project AsteroidsClone.xcodeproj -scheme AsteroidsClone -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.1' build

# Build for older iOS (specify iPhone 15 for iOS 18.x)
xcodebuild -project AsteroidsClone.xcodeproj -scheme AsteroidsClone -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' build
```

### UI Testing
```bash
# Run all UI tests
xcodebuild test -project AsteroidsClone.xcodeproj -scheme AsteroidsClone -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.1'

# Run specific test
xcodebuild test -project AsteroidsClone.xcodeproj -scheme AsteroidsClone -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.1' -only-testing:AsteroidsCloneUITests/AsteroidsCloneUITests/testFiring
```

### Config Server
```bash
# Start config server for hot-reload development
cd ConfigServer
python3 server.py  # Runs on port 8888, serves game_config.json
```

## Project-Specific Conventions

### File Organization
- **Game logic**: AsteroidsClone/*.swift (flat structure, no subdirectories)
- **Audio assets**: .wav files directly in AsteroidsClone/ (e.g., laser.wav, thrust.wav)
- **Documentation**: Root-level .md files (ARCHITECTURE.md, TESTING.md, DEVELOPMENT.md, AGENTS.md)
- **Config server**: ConfigServer/ with Python Flask server and game_config.json
- **UI tests**: AsteroidsCloneUITests/SimpleUITests.swift (SpriteKit-compatible coordinate-based tests)

### Naming Conventions
- **Scenes**: Suffix with "Scene" (GameScene, MenuScene, GameOverScene)
- **Managers**: Singleton pattern with `.shared` - suffix with "Manager" (GameManager, SoundManager, ConfigManager)
- **UI Controls**: Suffix with type (VirtualJoystick, FireButton, ShieldButton)
- **Constants**: PhysicsCategory, Constants.swift for game-wide values

### SKNode vs UIKit Accessibility
- **SpriteKit nodes**: Use `.name` property for identification (spaceship.name = "Spaceship")
- **Scene views**: Use `view?.accessibilityIdentifier` for scene identification
- **UI Testing limitation**: XCUITest CANNOT query individual SKNode elements - tests use coordinate-based taps
- **Test pattern**: `app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.85)).tap()`

### Configuration-Driven Gameplay
- **All tunable values**: Stored in ConfigManager (thrust force, rotation speed, spawn intervals, scoring)
- **Live updates**: Change game_config.json while game runs - ConfigManager polls and updates automatically
- **Computed properties**: Use `private var config: GameConfig { ConfigManager.shared.config }` for latest values
- **Example**: `spaceship.thrust(force: config.spaceship.thrustForce)` always uses current config

### Scene Lifecycle Pattern
```swift
override func didMove(to view: SKView) {
    self.view?.accessibilityIdentifier = "SceneName"  // For UI testing
    backgroundColor = SKColor.black
    // Setup physics, entities, HUD
    playerInputManager = PlayerInputManager(scene: self)
    playerInputManager.setupControls()
    playerInputManager.setupGameController()
    // Observe config/notifications
    NotificationCenter.default.addObserver(...)
}
```

### Demo Mode Implementation
- **Toggle**: GameScene.init(size:demoMode:true) enables AI control
- **AI logic**: In `update()` method - calculates angle to nearest asteroid, rotates ship, auto-fires
- **UI hiding**: PlayerInputManager hides joystick/buttons when `scene.isDemoMode == true`
- **Menu access**: "DEMO" option in MenuScene starts GameScene(size:demoMode:true)

## Testing Strategy

### UI Test Limitations
- **SpriteKit reality**: XCUITest can't query individual sprites, labels, or game objects
- **Workaround**: Coordinate-based interactions - tap normalized positions (0.0-1.0 range)
- **Test focus**: App stability, scene transitions, crash prevention - NOT game element validation
- **Example tests**: testAppLaunches, testFiring (taps fire button area), testScreenNavigation

### Manual Testing Checklist
- **Controller support**: Test MFi/Xbox/PlayStation controller via Bluetooth before release
- **Config server**: Verify hot-reload by changing thrustForce while playing - should feel immediate
- **Sound preloading**: First laser fire should have zero delay (MenuScene preloads all audio)
- **Game Center**: Test both authenticated and unauthenticated flows - no crashes either way

## Common Pitfalls

1. **Don't use UIKit accessibility on SKNodes**: `SKNode` has no `accessibilityIdentifier` - use `.name` instead
2. **Scene reference leaks**: Always use `[weak self]` in closures that capture scene
3. **Config polling lifecycle**: ConfigManager polls continuously - don't start additional timers
4. **Sound scene awareness**: Toggle `SoundManager.shared.setGameSceneActive()` on scene transitions
5. **Physics contact masks**: Must set BOTH `contactTestBitMask` AND `collisionBitMask` for collision detection
6. **Game Controller discovery**: Always observe both `.GCControllerDidConnect` and `.GCControllerDidDisconnect`
7. **Demo mode touches**: Input methods check `scene.isDemoMode` - don't process touches if true

## Integration Points

### External Dependencies
- **SpriteKit**: Apple's 2D game framework - no third-party frameworks used
- **GameController**: MFi controller support - standard iOS framework
- **GameKit**: Game Center leaderboards - requires App Store Connect configuration
- **Combine**: For ConfigManager reactive updates - native Swift framework

### Network Communication
- **Config server**: HTTP GET to `http://MacBook-Pro.local:8888/api/config` every 2 seconds
- **Game Center**: Apple's servers for leaderboard submission (handled by GameKit framework)
- **No analytics**: Game collects zero telemetry or user tracking data

## Quick Reference

### Add New Scene
1. Create `NewScene.swift` inheriting from `SKScene`
2. Add `self.view?.accessibilityIdentifier = "NewScene"` in `didMove(to:)`
3. Implement `touchesBegan` or use PlayerInputManager for input
4. Transition from existing scene: `view?.presentScene(NewScene(size: size))`

### Add New Configurable Parameter
1. Add property to appropriate struct in `ConfigModel.swift`
2. Add default value in `ConfigManager.defaultConfig()`
3. Update `game_config.json` in ConfigServer with new property
4. Access via `ConfigManager.shared.config.section.property`

### Add New Sound Effect
1. Place .wav file in `AsteroidsClone/` folder (alongside .swift files)
2. Add to Xcode project (drag into project navigator)
3. Play via `SoundManager.shared.playSound(filename: "newsound.wav")`
4. Preload in MenuScene: Add to preloadSounds completion

## Documentation Files
- **AGENTS.md**: Build commands and code style for AI agents
- **ARCHITECTURE.md**: System design and component interactions
- **TESTING.md**: Comprehensive testing strategy and test cases
- **DEVELOPMENT.md**: Development workflow and best practices
- **README.md**: User-facing project overview
