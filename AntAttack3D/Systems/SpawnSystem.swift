import Foundation
import SceneKit

/// Manages spawning of player, enemies, hostages, and safe zones
class SpawnSystem: GameSystem {
    weak var scene: GameScene3D?
    
    init() {}
    
    func setup() {
        // Spawning happens during scene setup
    }
    
    func update(deltaTime: TimeInterval) {
        // Spawn system is primarily setup-driven, no per-frame updates
    }
    
    // MARK: - Player Spawning
    
    /// Create player ball at starting position
    func createBall() {
        guard let scene = scene else { return }
        
        // Create sphere geometry
        let sphere = SCNSphere(radius: CGFloat(GameConstants.Collision.playerRadius))
        
        // Create material for the ball (white color)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.white
        material.lightingModel = GameConstants.Materials.lightingModel
        material.specular.contents = UIColor(white: 0.9, alpha: 1.0)
        sphere.materials = [material]
        
        // Create node for the ball
        let ballNode = SCNNode(geometry: sphere)
        ballNode.name = "Ball"
        
        // Position the ball at starting location (top-right corner)
        let mapWidth = Float(scene.cityMap.width)
        let mapHeight = Float(scene.cityMap.height)
        ballNode.position = SCNVector3(
            x: mapWidth - Float(GameConstants.Spawn.playerSpawnX),
            y: Float(GameConstants.Spawn.spawnHeightOffset),
            z: mapHeight - Float(GameConstants.Spawn.playerSpawnY)
        )
        
        // Enable physics for the ball
        let physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: sphere))
        physicsBody.mass = CGFloat(GameConstants.Physics.ballMass)
        physicsBody.restitution = CGFloat(GameConstants.Physics.ballRestitution)
        physicsBody.friction = CGFloat(GameConstants.Physics.ballFriction)
        physicsBody.rollingFriction = CGFloat(GameConstants.Physics.rollingFriction)
        physicsBody.damping = CGFloat(GameConstants.Physics.damping)
        physicsBody.angularDamping = CGFloat(GameConstants.Physics.angularDamping)
        
        ballNode.physicsBody = physicsBody
        
        scene.rootNode.addChildNode(ballNode)
        scene.ballNode = ballNode
        
        // Create safe mat marker at player's starting position
        createSafeMat(at: SCNVector3(x: mapWidth - 5, y: 0, z: mapHeight - 5))
        
        // Enable physics on the world
        scene.physicsWorld.speed = 1.0
        scene.physicsWorld.gravity = SCNVector3(0, CGFloat(GameConstants.Physics.gravity), 0)
    }
    
    /// Create safe mat marker at player's starting position
    private func createSafeMat(at position: SCNVector3) {
        guard let scene = scene else { return }
        
        // Create a square floor mat
        let matSize: CGFloat = CGFloat(GameConstants.Hostage.safeMatSize)
        let mat = SCNPlane(width: matSize, height: matSize)
        
        // Bright blue semi-transparent material for the safe zone
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(red: 0.0, green: 0.3, blue: 1.0, alpha: 0.5)
        material.lightingModel = GameConstants.Materials.lightingModel
        material.isDoubleSided = true
        mat.materials = [material]
        
        // Create node and position it
        let matNode = SCNNode(geometry: mat)
        matNode.name = "SafeMat"
        matNode.position = position
        
        // Rotate to lie flat on the ground
        matNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        
        // Add to scene
        scene.rootNode.addChildNode(matNode)
        
        // Store reference for collision detection
        scene.safeMatPosition = position
        scene.safeMatRadius = Float(matSize / 2)
    }
    
    // MARK: - Enemy Spawning
    
    /// Create enemy balls in corners
    func createEnemyBalls() {
        guard let scene = scene else { return }
        guard let gameStateSystem = scene.gameStateSystem else { return }
        
        // Clear any existing enemies
        scene.enemyBalls.forEach { $0.node.removeFromParentNode() }
        scene.enemyBalls.removeAll()
        
        // Get map dimensions
        let mapWidth = Float(scene.cityMap.width)
        let mapHeight = Float(scene.cityMap.height)
        
        // Define corner positions
        let cornerPositions: [(Float, Float)] = [
            (5, 5),                           // Near bottom-left corner
            (mapWidth - 5, 5),                // Near bottom-right corner
            (5, mapHeight - 5),               // Near top-left corner
            (mapWidth / 2, 5),                // Middle-bottom
            (5, mapHeight / 2),               // Middle-left
            (mapWidth - 5, mapHeight / 2)     // Middle-right
        ]
        
        // Calculate how many enemies for this level
        let numEnemies = min(
            gameStateSystem.baseEnemyCount + (gameStateSystem.currentLevel - 1) * GameConstants.Gameplay.enemyIncrement,
            GameConstants.Gameplay.maxEnemies
        )
        let actualNumEnemies = min(numEnemies, cornerPositions.count)
        
        // Create enemy at each corner position
        for i in 0..<actualNumEnemies {
            let (x, z) = cornerPositions[i]
            let position = SCNVector3(
                x: x,
                y: Float(GameConstants.Spawn.spawnHeightOffset),
                z: z
            )
            let enemy = EnemyBall(position: position)
            
            scene.rootNode.addChildNode(enemy.node)
            scene.enemyBalls.append(enemy)
        }
        
        print("🎮 Level \(gameStateSystem.currentLevel): Spawned \(actualNumEnemies) enemies")
    }
    
    // MARK: - Hostage Spawning
    
    /// Spawn hostages on raised blocks (safe from ground enemies)
    func createHostages() {
        guard let scene = scene else { return }
        guard let gameStateSystem = scene.gameStateSystem else { return }
        
        // Clear any existing hostages
        scene.hostages.forEach { $0.node.removeFromParentNode() }
        scene.hostages.removeAll()
        
        // Find suitable spawn positions (standing on blocks at z=1)
        var candidatePositions: [SCNVector3] = []
        
        print("🔍 DEBUG: Searching for hostage spawn positions...")
        print("🔍 DEBUG: Map size: \(scene.cityMap.width) x \(scene.cityMap.height)")
        
        // Look for blocks at z=1 to place hostages on top
        for x in 0..<scene.cityMap.width {
            for y in 0..<scene.cityMap.height {
                // Skip boundary walls
                if x == 0 || x == scene.cityMap.width - 1 || y == 0 || y == scene.cityMap.height - 1 {
                    continue
                }
                
                // Check if there's a block at z=1
                if scene.cityMap.hasBlock(x: x, y: y, z: 1) {
                    // Make sure there's space at z=2 and z=3
                    if !scene.cityMap.hasBlock(x: x, y: y, z: 2) &&
                       !scene.cityMap.hasBlock(x: x, y: y, z: 3) {
                        
                        let position = SCNVector3(x: Float(x), y: 3.0, z: Float(y))
                        
                        // Make sure it's not too close to player start
                        let playerStart = SCNVector3(
                            x: Float(scene.cityMap.width) - 5,
                            y: 0,
                            z: Float(scene.cityMap.height) - 5
                        )
                        let dx = position.x - playerStart.x
                        let dz = position.z - playerStart.z
                        let distToPlayer = sqrt(dx*dx + dz*dz)
                        
                        if distToPlayer > GameConstants.Spawn.minSpawnDistance {
                            candidatePositions.append(position)
                        }
                    }
                }
            }
        }
        
        // If no candidates at z=1, try z=0 (ground level)
        if candidatePositions.isEmpty {
            print("⚠️ No valid z=1 positions, trying z=0 (ground level)...")
            for x in 0..<scene.cityMap.width {
                for y in 0..<scene.cityMap.height {
                    if x == 0 || x == scene.cityMap.width - 1 || y == 0 || y == scene.cityMap.height - 1 {
                        continue
                    }
                    
                    if scene.cityMap.hasBlock(x: x, y: y, z: 0) {
                        if !scene.cityMap.hasBlock(x: x, y: y, z: 1) &&
                           !scene.cityMap.hasBlock(x: x, y: y, z: 2) {
                            
                            let position = SCNVector3(x: Float(x), y: 1.5, z: Float(y))
                            
                            let playerStart = SCNVector3(
                                x: Float(scene.cityMap.width) - 5,
                                y: 0,
                                z: Float(scene.cityMap.height) - 5
                            )
                            let dx = position.x - playerStart.x
                            let dz = position.z - playerStart.z
                            let distToPlayer = sqrt(dx*dx + dz*dz)
                            
                            if distToPlayer > GameConstants.Spawn.minSpawnDistance {
                                candidatePositions.append(position)
                            }
                        }
                    }
                }
            }
            print("🔍 DEBUG: Found \(candidatePositions.count) ground-level positions")
        }
        
        // Calculate how many hostages for this level
        let numHostages = min(
            gameStateSystem.baseHostageCount + (gameStateSystem.currentLevel - 1) * GameConstants.Gameplay.hostageIncrement,
            GameConstants.Gameplay.maxHostages
        )
        let actualNumHostages = min(candidatePositions.count, numHostages)
        
        // Use smart selection algorithm to spread hostages across the map
        var selectedPositions: [SCNVector3] = []
        var remainingCandidates = candidatePositions
        
        // Pick first hostage randomly
        if !remainingCandidates.isEmpty {
            let firstIndex = Int.random(in: 0..<remainingCandidates.count)
            selectedPositions.append(remainingCandidates[firstIndex])
            remainingCandidates.remove(at: firstIndex)
        }
        
        // Pick remaining hostages by maximizing minimum distance
        let minDesiredDistance: Float = Float(scene.cityMap.width) * 0.15
        
        while selectedPositions.count < actualNumHostages && !remainingCandidates.isEmpty {
            var bestCandidate: SCNVector3?
            var bestMinDistance: Float = 0
            
            for candidate in remainingCandidates {
                var minDistToSelected: Float = Float.greatestFiniteMagnitude
                for selected in selectedPositions {
                    let dx = candidate.x - selected.x
                    let dz = candidate.z - selected.z
                    let dist = sqrt(dx*dx + dz*dz)
                    minDistToSelected = min(minDistToSelected, dist)
                }
                
                if minDistToSelected > bestMinDistance {
                    bestMinDistance = minDistToSelected
                    bestCandidate = candidate
                }
            }
            
            if let best = bestCandidate {
                selectedPositions.append(best)
                remainingCandidates.removeAll { pos in
                    pos.x == best.x && pos.z == best.z
                }
            } else {
                break
            }
        }
        
        print("🎯 Selected \(selectedPositions.count) hostages with improved spacing")
        
        // Spawn hostages at selected positions
        for (i, spawnPos) in selectedPositions.enumerated() {
            let hostage = Hostage(position: spawnPos)
            scene.rootNode.addChildNode(hostage.node)
            scene.hostages.append(hostage)
            
            print("✅ Hostage \(i+1) spawned at: \(spawnPos)")
        }
        
        print("🎯 Spawned \(scene.hostages.count) total hostages")
        
        // Initialize HUD
        gameStateSystem.updateHostageCount()
    }
    
    func cleanup() {
        // Nothing to clean up
    }
}
