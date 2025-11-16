import Foundation
import SceneKit

/// Manages enemy AI, hostage behavior, and collision detection
class AISystem: GameSystem {
    weak var scene: GameScene3D?
    
    // MARK: - Enemy State
    private var lastEnemyUpdateTime: TimeInterval = 0
    
    init() {}
    
    func setup() {
        lastEnemyUpdateTime = CACurrentMediaTime()
    }
    
    func update(deltaTime: TimeInterval) {
        updateEnemyAI()
        updateHostages()
        checkEnemyCollision()
    }
    
    // MARK: - Enemy AI
    
    /// Update enemy AI (called every frame)
    private func updateEnemyAI() {
        guard let scene = scene else { return }
        guard let playerPosition = scene.ballNode?.presentation.position else { return }
        
        let currentTime = CACurrentMediaTime()
        let deltaTime = currentTime - lastEnemyUpdateTime
        lastEnemyUpdateTime = currentTime
        
        // Update each enemy
        for enemy in scene.enemyBalls {
            enemy.update(playerPosition: playerPosition, deltaTime: deltaTime, scene: scene, otherEnemies: scene.enemyBalls)
        }
    }
    
    /// Check distance-based collision with enemies
    private func checkEnemyCollision() {
        guard let scene = scene else { return }
        guard let gameStateSystem = scene.gameStateSystem else { return }
        
        // Don't check collisions if game is already over
        if gameStateSystem.isGameOver { return }
        
        guard let playerPosition = scene.ballNode?.presentation.position else { return }
        
        // Check distance to each enemy ball
        let collisionDistance: Float = 1.1
        
        for enemy in scene.enemyBalls {
            let enemyPosition = enemy.node.presentation.position
            let distance = playerPosition.distance(to: enemyPosition)
            
            if distance < collisionDistance {
                // Check line of sight to prevent catching through walls
                if hasLineOfSight(from: enemyPosition, to: playerPosition) {
                    print("Enemy collision detected - caught by enemy!")
                    gameStateSystem.triggerGameOver()
                    break
                }
            }
        }
    }
    
    /// Check if there's a clear line of sight between two positions
    private func hasLineOfSight(from start: SCNVector3, to end: SCNVector3) -> Bool {
        guard let scene = scene else { return false }
        
        let hitResults = scene.rootNode.hitTestWithSegment(from: start, to: end, options: nil)
        
        // Filter out hits with enemy balls, hostages, and the player ball itself
        for hit in hitResults {
            if let nodeName = hit.node.name {
                if nodeName == "Ball" || nodeName.contains("Enemy") || nodeName == "Hostage" || nodeName == "SafeMat" {
                    continue
                }
            }
            // Hit something else (a block) - no line of sight
            return false
        }
        
        // No obstacles found - clear line of sight
        return true
    }
    
    // MARK: - Hostage Behavior
    
    /// Update hostages - check for player collision and follow behavior
    private func updateHostages() {
        guard let scene = scene else { return }
        guard let playerPosition = scene.ballNode?.presentation.position else { return }
        guard let gameStateSystem = scene.gameStateSystem else { return }
        
        for hostage in scene.hostages {
            switch hostage.state {
            case .waiting:
                // Check if player is close enough to rescue this hostage
                let hostagePos = hostage.node.presentation.position
                let dx = playerPosition.x - hostagePos.x
                let dy = playerPosition.y - hostagePos.y
                let dz = playerPosition.z - hostagePos.z
                let distance = sqrt(dx*dx + dy*dy + dz*dz)
                
                if distance < GameConstants.Hostage.rescueDistance {
                    hostage.state = .following
                    print("Hostage rescued! Following player...")
                    
                    // Update HUD
                    gameStateSystem.updateHostageCount()
                }
                
            case .following:
                // Update follow behavior
                hostage.update(playerPosition: playerPosition)
                
                // Check if hostage reached the safe mat
                let hostagePos = hostage.node.presentation.position
                let dx = hostagePos.x - scene.safeMatPosition.x
                let dz = hostagePos.z - scene.safeMatPosition.z
                let distToMat = sqrt(dx*dx + dz*dz)
                
                if distToMat < scene.safeMatRadius {
                    hostage.state = .saved
                    
                    // Add points for saving this hostage
                    gameStateSystem.addScore(GameConstants.Gameplay.pointsPerHostage)
                    print("Hostage saved! +\(GameConstants.Gameplay.pointsPerHostage) points (Total: \(gameStateSystem.score))")
                    
                    // Make hostage vanish with fade animation
                    let fadeOut = SCNAction.fadeOut(duration: 0.5)
                    let remove = SCNAction.removeFromParentNode()
                    let sequence = SCNAction.sequence([fadeOut, remove])
                    hostage.node.runAction(sequence)
                    
                    // Update HUD
                    gameStateSystem.updateHostageCount()
                    
                    // Check if all hostages are saved (level complete!)
                    if scene.hostages.allSatisfy({ $0.state == .saved }) {
                        print("🎉 LEVEL \(gameStateSystem.currentLevel) COMPLETE! 🎉")
                        print("Final Score: \(gameStateSystem.score)")
                        
                        gameStateSystem.completeLevel()
                    }
                }
                
            case .saved:
                // Hostage is safe, no more updates needed
                break
            }
        }
    }
    
    func cleanup() {
        // Nothing to clean up
    }
}
