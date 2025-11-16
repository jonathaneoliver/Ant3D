import Foundation
import SceneKit

/// Manages game state, scoring, level progression, and game over conditions
class GameStateSystem: GameSystem {
    weak var scene: GameScene3D?
    
    // MARK: - Game State
    var score: Int = 0
    var currentLevel: Int = 1
    var isGameOver: Bool = false
    
    // MARK: - Level Configuration
    var baseHostageCount: Int = GameConstants.Gameplay.baseHostageCount
    var baseEnemyCount: Int = GameConstants.Gameplay.baseEnemyCount
    
    // MARK: - Callbacks
    var onScoreChanged: ((Int) -> Void)?
    var onLevelComplete: ((Int) -> Void)?
    var onHostageCountChanged: ((Int, Int) -> Void)?
    var onGameOver: (() -> Void)?
    
    init() {}
    
    func setup() {
        // Send initial hostage count
        updateHostageCount()
    }
    
    func update(deltaTime: TimeInterval) {
        // Game state is primarily event-driven, no per-frame updates needed
    }
    
    // MARK: - Scoring
    
    /// Add points to the current score
    func addScore(_ points: Int) {
        score += points
        onScoreChanged?(score)
    }
    
    // MARK: - Level Progression
    
    /// Complete the current level and advance to next
    func completeLevel() {
        currentLevel += 1
        onLevelComplete?(currentLevel)
        
        // Wait 2 seconds, then restart with next level
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.restartLevel()
        }
    }
    
    /// Restart level with current difficulty
    func restartLevel() {
        guard let scene = scene else { return }
        guard let spawnSystem = scene.spawnSystem else { return }
        
        print("🔄 Restarting with Level \(currentLevel)...")
        
        // Reset game over flag
        isGameOver = false
        
        // Reset player position to starting location
        let mapWidth = Float(scene.cityMap.width)
        let mapHeight = Float(scene.cityMap.height)
        let startPosition = SCNVector3(x: mapWidth - 5, y: 5, z: mapHeight - 5)
        scene.ballNode?.position = startPosition
        scene.ballNode?.physicsBody?.velocity = SCNVector3Zero
        scene.ballNode?.physicsBody?.angularVelocity = SCNVector4Zero
        
        // Recreate enemies and hostages with new count
        spawnSystem.createEnemyBalls()
        spawnSystem.createHostages()
        
        print("✅ Level \(currentLevel) started: \(scene.hostages.count) hostages, \(scene.enemyBalls.count) enemies")
    }
    
    // MARK: - Game Over
    
    /// Trigger game over (called when enemy catches player)
    func triggerGameOver() {
        isGameOver = true
        
        // Submit score to Game Center
        GameCenterManager.shared.submitScore(score)
        
        // Trigger callback
        onGameOver?()
    }
    
    /// Reset game over flag (called when restarting)
    func resetGameOver() {
        isGameOver = false
    }
    
    // MARK: - HUD Updates
    
    /// Update hostage count in HUD
    func updateHostageCount() {
        guard let scene = scene else { return }
        let savedCount = scene.hostages.filter { $0.state == .saved }.count
        onHostageCountChanged?(savedCount, scene.hostages.count)
    }
    
    func cleanup() {
        // Nothing to clean up
    }
}
