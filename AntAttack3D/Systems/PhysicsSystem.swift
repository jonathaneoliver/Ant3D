import Foundation
import SceneKit

/// Movement states for the player ball
enum MovementState {
    case groundedWalking
    case climbingWall(phase: ClimbPhase, targetY: Float, wallNormal: SCNVector3, platformCenter: SCNVector3?)
    case falling(velocity: Float)
}

/// Phases of wall climbing
enum ClimbPhase {
    case ascending          // Moving up the wall
    case reachingTop        // Just reached target height
    case centeringOnPlatform // Moving onto block center
}

/// Handles player ball movement using direct position-based control
/// No longer uses physics simulation for player movement (kinematic mode)
class PhysicsSystem: GameSystem {
    weak var scene: GameScene3D?
    
    // MARK: - Controller Input State
    private var currentMoveX: Float = 0.0
    private var currentMoveZ: Float = 0.0
    private var isJumping: Bool = false
    
    // MARK: - Movement State
    private var currentState: MovementState = .groundedWalking
    
    // Movement constants
    private let walkSpeed: Float = 8.0
    private let climbSpeed: Float = 6.0
    private let climbCenteringSpeed: Float = 8.0
    private let fallGravity: Float = -20.0
    private let maxFallSpeed: Float = -50.0
    private let ballRadius: Float = 0.5
    
    // Raycast distances
    private let groundCheckDistance: Float = 0.7
    private let wallCheckDistance: Float = 1.5
    private let climbForwardDistance: Float = 1.0  // How far forward to center on platform
    
    init() {}
    
    func setup() {
        // Movement is now position-based, no special physics setup needed
    }
    
    func update(deltaTime: TimeInterval) {
        guard let scene = scene, let ballNode = scene.ballNode else { return }
        
        switch currentState {
        case .groundedWalking:
            updateGroundedWalking(ballNode: ballNode, deltaTime: deltaTime)
            
        case .climbingWall(let phase, let targetY, let wallNormal, let platformCenter):
            updateClimbing(ballNode: ballNode, deltaTime: deltaTime, phase: phase, targetY: targetY, wallNormal: wallNormal, platformCenter: platformCenter)
            
        case .falling(let velocity):
            updateFalling(ballNode: ballNode, deltaTime: deltaTime, velocity: velocity)
        }
    }
    
    // MARK: - Input Methods (called by InputManager)
    
    /// Set movement direction from controller input
    func moveBall(x: Float, z: Float) {
        currentMoveX = x
        currentMoveZ = z
    }
    
    /// Start wall-climbing mode
    func jumpBall() {
        isJumping = true
    }
    
    /// Stop wall-climbing mode
    func releaseJump() {
        isJumping = false
    }
    
    // MARK: - State Updates
    
    private func updateGroundedWalking(ballNode: SCNNode, deltaTime: TimeInterval) {
        // Check if climb button pressed and wall ahead
        if isJumping {
            if let climbInfo = checkForClimbableWall(ballNode: ballNode) {
                // Start climbing
                currentState = .climbingWall(
                    phase: .ascending,
                    targetY: climbInfo.topY,
                    wallNormal: climbInfo.wallNormal,
                    platformCenter: nil
                )
                return
            }
        }
        
        // Apply joystick movement directly to position
        let speed = walkSpeed * Float(deltaTime)
        var newPosition = ballNode.position
        newPosition.x += CGFloat(currentMoveX * speed)
        newPosition.z += CGFloat(currentMoveZ * speed)
        
        // Check if ground exists at new position
        if let groundY = raycastGroundHeight(at: newPosition) {
            // Ground exists - move there
            newPosition.y = groundY + CGFloat(ballRadius)
            ballNode.position = newPosition
        } else {
            // No ground - check if we should fall
            if let _ = raycastGroundHeight(at: ballNode.position) {
                // Still on current ground, don't move
            } else {
                // No ground under current position either - start falling
                currentState = .falling(velocity: 0)
            }
        }
    }
    
    private func updateClimbing(ballNode: SCNNode, deltaTime: TimeInterval, phase: ClimbPhase, targetY: Float, wallNormal: SCNVector3, platformCenter: SCNVector3?) {
        let dt = Float(deltaTime)
        
        switch phase {
        case .ascending:
            // Move up the wall
            var newPosition = ballNode.position
            newPosition.y += CGFloat(climbSpeed * dt)
            
            // Hug the wall slightly (move opposite to wall normal)
            newPosition.x -= CGFloat(wallNormal.x * 0.3 * dt)
            newPosition.z -= CGFloat(wallNormal.z * 0.3 * dt)
            
            ballNode.position = newPosition
            
            // Check if reached top
            if Float(ballNode.position.y) >= targetY {
                // Transition to reaching top phase
                currentState = .climbingWall(
                    phase: .reachingTop,
                    targetY: targetY,
                    wallNormal: wallNormal,
                    platformCenter: nil
                )
            }
            
        case .reachingTop:
            // Calculate platform center position
            let forwardDirection = SCNVector3(x: -wallNormal.x, y: 0, z: -wallNormal.z)
            let centerPos = findPlatformCenter(fromPosition: ballNode.position, direction: forwardDirection)
            
            // Snap Y to target height
            ballNode.position.y = CGFloat(targetY)
            
            // Transition to centering phase
            currentState = .climbingWall(
                phase: .centeringOnPlatform,
                targetY: targetY,
                wallNormal: wallNormal,
                platformCenter: centerPos
            )
            
        case .centeringOnPlatform:
            guard let platformCenter = platformCenter else {
                // No center calculated - just finish
                currentState = .groundedWalking
                return
            }
            
            // Move toward platform center
            let toCenter = SCNVector3(
                x: Float(platformCenter.x - ballNode.position.x),
                y: 0,
                z: Float(platformCenter.z - ballNode.position.z)
            )
            let distance = sqrt(toCenter.x * toCenter.x + toCenter.z * toCenter.z)
            
            if distance < 0.1 {
                // Reached center - done climbing
                ballNode.position = platformCenter
                currentState = .groundedWalking
            } else {
                // Move toward center
                let moveDistance = climbCenteringSpeed * dt
                if distance > moveDistance {
                    let normalizedMove = SCNVector3(
                        x: toCenter.x / distance,
                        y: 0,
                        z: toCenter.z / distance
                    )
                    ballNode.position.x += CGFloat(normalizedMove.x * moveDistance)
                    ballNode.position.z += CGFloat(normalizedMove.z * moveDistance)
                } else {
                    // Close enough - snap to center
                    ballNode.position = platformCenter
                    currentState = .groundedWalking
                }
            }
        }
    }
    
    private func updateFalling(ballNode: SCNNode, deltaTime: TimeInterval, velocity: Float) {
        let dt = Float(deltaTime)
        
        // Apply gravity
        var newVelocity = velocity + fallGravity * dt
        newVelocity = max(newVelocity, maxFallSpeed)  // Cap fall speed
        
        // Update position
        var newPosition = ballNode.position
        newPosition.y += CGFloat(newVelocity * dt)
        
        // Check for ground
        if let groundY = raycastGroundHeight(at: newPosition) {
            if Float(newPosition.y) <= groundY + ballRadius {
                // Landed
                newPosition.y = groundY + CGFloat(ballRadius)
                ballNode.position = newPosition
                currentState = .groundedWalking
                return
            }
        }
        
        // Still falling
        ballNode.position = newPosition
        currentState = .falling(velocity: newVelocity)
    }
    
    // MARK: - Helper Functions
    
    private func raycastGroundHeight(at position: SCNVector3) -> CGFloat? {
        guard let scene = scene else { return nil }
        
        let rayStart = SCNVector3(x: position.x, y: position.y + 0.5, z: position.z)
        let rayEnd = SCNVector3(x: position.x, y: position.y - CGFloat(groundCheckDistance), z: position.z)
        
        let hitResults = scene.rootNode.hitTestWithSegment(from: rayStart, to: rayEnd, options: [
            SCNHitTestOption.searchMode.rawValue: SCNHitTestSearchMode.closest.rawValue,
            SCNHitTestOption.backFaceCulling.rawValue: false
        ])
        
        for hit in hitResults {
            if hit.node != scene.ballNode {
                return hit.worldCoordinates.y
            }
        }
        
        return nil
    }
    
    private func checkForClimbableWall(ballNode: SCNNode) -> (topY: Float, wallNormal: SCNVector3)? {
        guard let scene = scene else { return nil }
        guard let cameraSystem = scene.cameraSystem else { return nil }
        
        // Transform joystick input to world space
        let cameraAngleRadians = cameraSystem.cameraOrbitAngle * Float.pi / 180.0
        let worldX = currentMoveX * cos(cameraAngleRadians) + currentMoveZ * sin(cameraAngleRadians)
        let worldZ = -currentMoveX * sin(cameraAngleRadians) + currentMoveZ * cos(cameraAngleRadians)
        
        // Only check if there's movement input
        let inputMagnitude = sqrt(worldX * worldX + worldZ * worldZ)
        guard inputMagnitude > 0.1 else { return nil }
        
        // Normalize direction
        let dirX = worldX / inputMagnitude
        let dirZ = worldZ / inputMagnitude
        
        // Cast ray forward to detect wall
        let ballPosition = ballNode.position
        let rayStart = SCNVector3(
            x: ballPosition.x + CGFloat(dirX * 0.2),
            y: ballPosition.y + 0.5,
            z: ballPosition.z + CGFloat(dirZ * 0.2)
        )
        let rayEnd = SCNVector3(
            x: ballPosition.x + CGFloat(dirX * wallCheckDistance),
            y: ballPosition.y + 0.5,
            z: ballPosition.z + CGFloat(dirZ * wallCheckDistance)
        )
        
        let hitResults = scene.rootNode.hitTestWithSegment(from: rayStart, to: rayEnd, options: [
            SCNHitTestOption.searchMode.rawValue: SCNHitTestSearchMode.closest.rawValue,
            SCNHitTestOption.backFaceCulling.rawValue: false
        ])
        
        for hit in hitResults {
            if hit.node != ballNode {
                let normal = hit.worldNormal
                
                // Check if this is a vertical wall (not floor/ceiling)
                let horizontalDot = sqrt(normal.x * normal.x + normal.z * normal.z)
                if horizontalDot > 0.7 {
                    // This is a wall - find the top
                    if let topY = findWallTop(from: ballPosition, direction: SCNVector3(x: dirX, y: 0, z: dirZ)) {
                        return (topY: Float(topY), wallNormal: normal)
                    }
                }
            }
        }
        
        return nil
    }
    
    private func findWallTop(from position: SCNVector3, direction: SCNVector3) -> CGFloat? {
        guard let scene = scene else { return nil }
        
        // Cast ray upward to find top of wall
        let rayStart = SCNVector3(x: position.x, y: position.y, z: position.z)
        let rayEnd = SCNVector3(x: position.x, y: position.y + 20.0, z: position.z)
        
        let hitResults = scene.rootNode.hitTestWithSegment(from: rayStart, to: rayEnd, options: [
            SCNHitTestOption.searchMode.rawValue: SCNHitTestSearchMode.all.rawValue,
            SCNHitTestOption.backFaceCulling.rawValue: false
        ])
        
        // Find highest horizontal surface above us
        var highestY: CGFloat = position.y + 1.0  // At least climb 1 unit
        
        for hit in hitResults {
            if hit.node != scene.ballNode {
                let normal = hit.worldNormal
                // Check if this is a horizontal surface (floor/ceiling)
                if abs(normal.y) > 0.9 && normal.y > 0 {
                    // This is a floor - potential top of wall
                    highestY = max(highestY, hit.worldCoordinates.y)
                }
            }
        }
        
        return highestY
    }
    
    private func findPlatformCenter(fromPosition: SCNVector3, direction: SCNVector3) -> SCNVector3 {
        // Move forward by climbForwardDistance
        var centerPos = SCNVector3(
            x: fromPosition.x + CGFloat(direction.x * climbForwardDistance),
            y: fromPosition.y,
            z: fromPosition.z + CGFloat(direction.z * climbForwardDistance)
        )
        
        // Snap to block center (blocks are 1.0 units, centers at 0.5, 1.5, 2.5, etc.)
        centerPos.x = floor(centerPos.x) + 0.5
        centerPos.z = floor(centerPos.z) + 0.5
        
        // Find ground height at this position
        if let groundY = raycastGroundHeight(at: centerPos) {
            centerPos.y = groundY + CGFloat(ballRadius)
        }
        
        return centerPos
    }
    
    func cleanup() {
        // Nothing to clean up
    }
}
