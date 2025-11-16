import SceneKit
import Foundation

// AI state for enemy balls
enum EnemyState {
    case chase      // Chasing player (has line of sight)
    case search     // Moving to last known position (lost sight)
    case wander     // Random wandering (no recent player sighting)
}

// Enemy ball class with AI behavior
class EnemyBall {
    let node: SCNNode
    var state: EnemyState = .wander {
        didSet {
            // Update color when state changes
            if state != oldValue {
                updateColor()
            }
        }
    }
    var lastSeenPlayerPosition: SCNVector3?
    var lastSeenTime: TimeInterval = 0
    var lastMoveDirection: SCNVector3?  // Direction enemy was moving when they last saw player
    var wanderTarget: SCNVector3?
    var wanderTimer: TimeInterval = 0
    
    // AI configuration
    var sightDistance: Float = GameConstants.Enemy.sightDistance
    var speedMultiplier: Float = GameConstants.Enemy.speedMultiplier
    var searchTimeout: TimeInterval = GameConstants.Enemy.searchTimeout
    
    // Movement parameters
    private let baseSpeed: Float = GameConstants.Enemy.baseSpeed
    
    init(position: SCNVector3) {
        // Create sphere geometry (same size as player ball)
        let sphere = SCNSphere(radius: CGFloat(GameConstants.Collision.enemyRadius))
        
        // Gray material for enemy (default wander state)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.black  // Black for wandering
        material.lightingModel = .lambert
        material.specular.contents = UIColor(white: 0.2, alpha: 1.0)
        sphere.materials = [material]
        
        // Create node
        node = SCNNode(geometry: sphere)
        node.name = "EnemyBall"
        node.position = position
        
        // Add physics body
        let physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: sphere))
        physicsBody.mass = 1.0
        physicsBody.restitution = 0.3
        physicsBody.friction = 0.8
        physicsBody.rollingFriction = 0.3
        physicsBody.damping = 0.1
        physicsBody.angularDamping = 0.1
        
        node.physicsBody = physicsBody
    }
    
    // Update enemy color based on current state
    private func updateColor() {
        guard let material = node.geometry?.firstMaterial else { return }
        
        // Animate color change for smooth transitions
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.3
        
        switch state {
        case .chase:
            // Red = Chasing player (can see you!)
            material.diffuse.contents = UIColor.red
        case .search:
            // Orange = Searching for player (lost sight, going to last known position)
            material.diffuse.contents = UIColor.orange
        case .wander:
            // Black = Wandering (no recent player sighting)
            material.diffuse.contents = UIColor.black
        }
        
        SCNTransaction.commit()
    }
    
    // Update AI behavior (called every frame)
    func update(playerPosition: SCNVector3, deltaTime: TimeInterval, scene: SCNScene, otherEnemies: [EnemyBall]) {
        let currentPosition = node.presentation.position
        
        // Check line of sight to player
        let hasLineOfSight = checkLineOfSight(to: playerPosition, from: currentPosition, scene: scene)
        let distanceToPlayer = currentPosition.distance(to: playerPosition)
        
        // Update state based on line of sight and distance
        if hasLineOfSight && distanceToPlayer <= sightDistance {
            // Can see player - chase
            state = .chase
            lastSeenPlayerPosition = playerPosition
            lastSeenTime = CACurrentMediaTime()
            
            // Track direction we're moving toward player
            let direction = SCNVector3(
                x: playerPosition.x - currentPosition.x,
                y: 0,
                z: playerPosition.z - currentPosition.z
            )
            let length = sqrt(direction.x * direction.x + direction.z * direction.z)
            if length > 0.1 {
                lastMoveDirection = SCNVector3(x: direction.x / length, y: 0, z: direction.z / length)
            }
        } else if let lastSeen = lastSeenPlayerPosition {
            // Lost sight - search for player
            let timeSinceLastSeen = CACurrentMediaTime() - lastSeenTime
            if timeSinceLastSeen < searchTimeout {
                state = .search
            } else {
                // Been too long - start wandering
                state = .wander
                lastSeenPlayerPosition = nil
            }
        } else {
            // No recent sighting - wander
            state = .wander
        }
        
        // Execute behavior based on state
        switch state {
        case .chase:
            chase(toward: playerPosition)
        case .search:
            if let target = lastSeenPlayerPosition {
                search(toward: target)
            }
        case .wander:
            wander(deltaTime: deltaTime, otherEnemies: otherEnemies, scene: scene)
        }
    }
    
    // Check if there's a clear line of sight to target position
    private func checkLineOfSight(to target: SCNVector3, from origin: SCNVector3, scene: SCNScene) -> Bool {
        // Cast ray from enemy position to player position
        // Raise ray slightly to avoid hitting ground
        let rayStart = SCNVector3(x: origin.x, y: origin.y + 0.5, z: origin.z)
        let rayEnd = SCNVector3(x: target.x, y: target.y + 0.5, z: target.z)
        
        let hitResults = scene.rootNode.hitTestWithSegment(from: rayStart, to: rayEnd, options: [
            SCNHitTestOption.searchMode.rawValue: SCNHitTestSearchMode.closest.rawValue,
            SCNHitTestOption.backFaceCulling.rawValue: false
        ])
        
        // Check if ray hits anything (walls/blocks) before reaching player
        for hit in hitResults {
            // Ignore self and player ball
            if hit.node == node || hit.node.name == "Ball" {
                continue
            }
            // Hit an obstacle - no line of sight
            return false
        }
        
        // No obstacles - clear line of sight
        return true
    }
    
    // Chase behavior - move directly toward player
    private func chase(toward target: SCNVector3) {
        guard let physicsBody = node.physicsBody else { return }
        
        let currentPosition = node.presentation.position
        let direction = SCNVector3(
            x: target.x - currentPosition.x,
            y: 0,  // No vertical movement (can't climb)
            z: target.z - currentPosition.z
        )
        
        // Normalize direction
        let length = sqrt(direction.x * direction.x + direction.z * direction.z)
        if length > 0.1 {
            let normalized = SCNVector3(x: direction.x / length, y: 0, z: direction.z / length)
            
            // Apply velocity at 75% of player speed
            let speed = baseSpeed * speedMultiplier
            physicsBody.velocity.x = normalized.x * speed
            physicsBody.velocity.z = normalized.z * speed
            // Don't touch Y velocity - let gravity handle it
        }
    }
    
    // Search behavior - move toward last known position
    private func search(toward target: SCNVector3) {
        guard let physicsBody = node.physicsBody else { return }
        
        let currentPosition = node.presentation.position
        let distance = sqrt(
            pow(target.x - currentPosition.x, 2) +
            pow(target.z - currentPosition.z, 2)
        )
        
        // If we've reached the last known position, keep going in that direction
        if distance < 1.0 {
            // Continue in the direction we were moving
            if let moveDirection = lastMoveDirection {
                // Project a new target point ahead in the same direction
                let continueDistance: Float = 10.0
                let newTarget = SCNVector3(
                    x: currentPosition.x + moveDirection.x * continueDistance,
                    y: currentPosition.y,
                    z: currentPosition.z + moveDirection.z * continueDistance
                )
                
                // Apply velocity in that direction
                let speed = baseSpeed * speedMultiplier
                physicsBody.velocity.x = moveDirection.x * speed
                physicsBody.velocity.z = moveDirection.z * speed
                
                // Update last seen position to the new projected target
                // so we keep searching in that direction
                lastSeenPlayerPosition = newTarget
            } else {
                // No direction tracked - fallback to wandering
                lastSeenPlayerPosition = nil
                state = .wander
            }
            return
        }
        
        // Move toward last known position (same as chase)
        chase(toward: target)
    }
    
    // Wander behavior - random movement with avoidance of other enemies
    private func wander(deltaTime: TimeInterval, otherEnemies: [EnemyBall], scene: SCNScene) {
        guard let physicsBody = node.physicsBody else { return }
        
        let currentPosition = node.presentation.position
        
        // Check if we can see any other enemies nearby
        var visibleEnemies: [SCNVector3] = []
        for other in otherEnemies {
            // Skip self
            if other.node == self.node { continue }
            
            // Only avoid other wandering enemies (don't interfere with chase/search)
            guard other.state == .wander else { continue }
            
            let otherPosition = other.node.presentation.position
            let distance = currentPosition.distance(to: otherPosition)
            
            // Check if enemy is close and visible
            if distance < sightDistance {
                if checkLineOfSight(to: otherPosition, from: currentPosition, scene: scene) {
                    visibleEnemies.append(otherPosition)
                }
            }
        }
        
        // If we see other enemies, pick a direction away from them
        if !visibleEnemies.isEmpty {
            // Calculate average position of visible enemies
            var avgX: Float = 0
            var avgZ: Float = 0
            for enemyPos in visibleEnemies {
                avgX += enemyPos.x
                avgZ += enemyPos.z
            }
            avgX /= Float(visibleEnemies.count)
            avgZ /= Float(visibleEnemies.count)
            
            // Move away from the average position
            let awayDirection = SCNVector3(
                x: currentPosition.x - avgX,
                y: 0,
                z: currentPosition.z - avgZ
            )
            
            let length = sqrt(awayDirection.x * awayDirection.x + awayDirection.z * awayDirection.z)
            if length > 0.1 {
                // Pick a new wander target in the opposite direction from other enemies
                let distance: Float = GameConstants.Enemy.avoidanceDistance  // Go farther when avoiding others
                wanderTarget = SCNVector3(
                    x: currentPosition.x + (awayDirection.x / length) * distance,
                    y: currentPosition.y,
                    z: currentPosition.z + (awayDirection.z / length) * distance
                )
                wanderTimer = GameConstants.Enemy.wanderInterval
            }
        } else {
            // Normal wandering - no enemies visible
            wanderTimer -= deltaTime
            
            // Pick new wander target every 3 seconds
            if wanderTimer <= 0 || wanderTarget == nil {
                // Random direction
                let angle = Float.random(in: 0...(2 * Float.pi))
                let distance: Float = GameConstants.Enemy.wanderTargetDistance
                wanderTarget = SCNVector3(
                    x: currentPosition.x + cos(angle) * distance,
                    y: currentPosition.y,
                    z: currentPosition.z + sin(angle) * distance
                )
                wanderTimer = GameConstants.Enemy.wanderInterval
            }
        }
        
        // Move toward wander target at half speed
        if let target = wanderTarget {
            let direction = SCNVector3(
                x: target.x - currentPosition.x,
                y: 0,
                z: target.z - currentPosition.z
            )
            
            let length = sqrt(direction.x * direction.x + direction.z * direction.z)
            if length > 0.5 {
                let normalized = SCNVector3(x: direction.x / length, y: 0, z: direction.z / length)
                let speed = baseSpeed * speedMultiplier * 0.5  // Wander at half chase speed
                physicsBody.velocity.x = normalized.x * speed
                physicsBody.velocity.z = normalized.z * speed
            } else {
                // Reached wander target - pick new one
                wanderTarget = nil
            }
        }
    }
}
