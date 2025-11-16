import Foundation
import SceneKit

/// Handles player ball physics, movement, climbing, and ground detection
class PhysicsSystem: GameSystem {
    weak var scene: GameScene3D?
    
    // MARK: - Controller Input State
    private var currentMoveX: Float = 0.0
    private var currentMoveZ: Float = 0.0
    private var isJumping: Bool = false
    
    // MARK: - Ground & Slope Detection
    private var isOnSlope: Bool = false
    private var slopeNormal: SCNVector3 = SCNVector3(0, 1, 0)
    private var lastGroundCheckTime: TimeInterval = 0
    private var isGrounded: Bool = false
    private var normalRestitution: CGFloat = 0.3
    private var normalFriction: CGFloat = 0.8
    
    init() {}
    
    func setup() {
        // Physics is set up when ball is created
    }
    
    func update(deltaTime: TimeInterval) {
        updateBallPhysics()
    }
    
    // MARK: - Movement Control
    
    /// Set movement direction from controller input
    func moveBall(x: Float, z: Float) {
        currentMoveX = x
        currentMoveZ = z
    }
    
    /// Set movement direction with direct velocity (legacy method)
    func moveBall(direction: SCNVector3) {
        guard let scene = scene, let ballNode = scene.ballNode else { return }
        guard let physicsBody = ballNode.physicsBody else { return }
        
        let speed: Float = GameConstants.Movement.playerSpeed
        let newVelocity = SCNVector3(
            x: direction.x * speed,
            y: physicsBody.velocity.y,  // Preserve vertical velocity
            z: direction.z * speed
        )
        physicsBody.velocity = newVelocity
    }
    
    /// Start wall-climbing mode
    func jumpBall() {
        guard let scene = scene, let ballNode = scene.ballNode else { return }
        guard let physicsBody = ballNode.physicsBody else { return }
        
        isJumping = true
        
        // Reduce restitution to prevent bouncing off walls
        physicsBody.restitution = 0.0
        physicsBody.friction = 2.0
    }
    
    /// Stop wall-climbing mode
    func releaseJump() {
        guard let scene = scene, let ballNode = scene.ballNode else { return }
        guard let physicsBody = ballNode.physicsBody else { return }
        
        isJumping = false
        
        // Cancel upward velocity immediately
        if physicsBody.velocity.y > 0 {
            physicsBody.velocity.y = 0
        }
        
        // Restore normal physics properties
        physicsBody.restitution = normalRestitution
        physicsBody.friction = normalFriction
    }
    
    // MARK: - Physics Update
    
    /// Update ball physics based on current input (called every frame)
    private func updateBallPhysics() {
        guard let scene = scene, let ballNode = scene.ballNode else { return }
        guard let physicsBody = ballNode.physicsBody else { return }
        guard let cameraSystem = scene.cameraSystem else { return }
        
        // Check ground/slope state
        checkGroundState()
        
        // Transform input to be camera-relative
        let cameraAngleRadians = cameraSystem.cameraOrbitAngle * Float.pi / 180.0
        
        // Rotate input vector by camera angle
        let worldX = currentMoveX * cos(cameraAngleRadians) + currentMoveZ * sin(cameraAngleRadians)
        let worldZ = -currentMoveX * sin(cameraAngleRadians) + currentMoveZ * cos(cameraAngleRadians)
        
        // Calculate movement direction and speed
        let speed: Float = GameConstants.Movement.playerSpeed
        var moveDirection = SCNVector3(x: worldX, y: 0, z: worldZ)
        
        // Apply slope climbing assistance if on a slope and moving
        var dampingFactor: Float = 1.0
        if isOnSlope && (abs(worldX) > 0.1 || abs(worldZ) > 0.1) {
            let normalizedMove = normalize(moveDirection)
            let upDot = dot(normalizedMove, slopeNormal)
            
            // If moving uphill
            if upDot < 0 {
                let slopeAngle = acos(slopeNormal.y)
                let climbAssist: Float = tan(slopeAngle) * 40.0
                moveDirection.y = climbAssist
            } else if upDot > 0 {
                // Going downhill - apply damping
                dampingFactor = 0.5
            }
        }
        
        // Check for wall climbing mode
        var climbingWall = false
        if isJumping {
            let wallCheck = checkWallAhead()
            
            if wallCheck.hasWall && wallCheck.distance < 0.6 {
                climbingWall = true
                
                let climbSpeed: Float = GameConstants.Movement.climbSpeed
                moveDirection.y = climbSpeed
                
                // Constrain horizontal movement to cardinal directions
                if abs(worldX) > abs(worldZ) {
                    moveDirection.x = worldX > 0 ? abs(worldX) : -abs(worldX)
                    moveDirection.z = 0
                } else {
                    moveDirection.x = 0
                    moveDirection.z = worldZ > 0 ? abs(worldZ) : -abs(worldZ)
                }
            }
        }
        
        // Apply movement - only if there's input or we're in a special state
        let hasMovementInput = abs(currentMoveX) > 0.01 || abs(currentMoveZ) > 0.01
        let shouldOverrideY = climbingWall || (isOnSlope && moveDirection.y != 0)
        
        if shouldOverrideY {
            // Climbing or slope assist - set all 3 velocity components
            let newVelocity = SCNVector3(
                x: moveDirection.x * speed * dampingFactor,
                y: moveDirection.y,
                z: moveDirection.z * speed * dampingFactor
            )
            physicsBody.velocity = newVelocity
        } else if hasMovementInput && (isGrounded || isJumping) {
            // Normal movement - allow horizontal movement when grounded OR when jump button is held
            // (Jump button allows repositioning while climbing, but without wall = no vertical climb)
            physicsBody.velocity.x = moveDirection.x * speed * dampingFactor
            physicsBody.velocity.z = moveDirection.z * speed * dampingFactor
        }
        // If not grounded, not jumping, and no input, let physics (gravity) handle everything
        
        // Apply damping to downhill velocity
        if isOnSlope {
            let currentVel = physicsBody.velocity
            let velDot = dot(SCNVector3(x: currentVel.x, y: 0, z: currentVel.z), slopeNormal)
            if velDot > 0 {
                physicsBody.velocity = SCNVector3(
                    x: currentVel.x * 0.9,
                    y: currentVel.y,
                    z: currentVel.z * 0.9
                )
            }
        }
    }
    
    // MARK: - Ground & Wall Detection
    
    /// Check if ball is on ground or slope using raycasting
    private func checkGroundState() {
        guard let scene = scene, let ballNode = scene.ballNode else { return }
        
        let currentTime = CACurrentMediaTime()
        if currentTime - lastGroundCheckTime < 0.05 {
            return
        }
        lastGroundCheckTime = currentTime
        
        let ballPosition = ballNode.presentation.position
        
        // Cast ray downward from ball center
        let rayStart = ballPosition
        let rayEnd = SCNVector3(x: ballPosition.x, y: ballPosition.y - 0.6, z: ballPosition.z)
        
        let hitResults = scene.rootNode.hitTestWithSegment(from: rayStart, to: rayEnd, options: [
            SCNHitTestOption.searchMode.rawValue: SCNHitTestSearchMode.all.rawValue,
            SCNHitTestOption.backFaceCulling.rawValue: false
        ])
        
        // Find first hit that isn't the ball itself
        for hit in hitResults {
            if hit.node != ballNode {
                let normal = hit.worldNormal
                
                isGrounded = true
                
                // Check if we're on a slope
                let verticalDot = abs(normal.y)
                if verticalDot < 0.98 {  // Not vertical (< ~11 degrees from horizontal)
                    isOnSlope = true
                    slopeNormal = normal
                } else {
                    isOnSlope = false
                    slopeNormal = SCNVector3(0, 1, 0)
                }
                return
            }
        }
        
        // No ground detected - ball is in the air
        isGrounded = false
        isOnSlope = false
        slopeNormal = SCNVector3(0, 1, 0)
    }
    
    /// Check if there's a wall in front of the ball
    private func checkWallAhead() -> (hasWall: Bool, distance: Float, normal: SCNVector3) {
        guard let scene = scene, let ballNode = scene.ballNode else {
            return (false, 0, SCNVector3(0, 1, 0))
        }
        guard let cameraSystem = scene.cameraSystem else {
            return (false, 0, SCNVector3(0, 1, 0))
        }
        
        let ballPosition = ballNode.presentation.position
        
        // Calculate movement direction in world space
        let cameraAngleRadians = cameraSystem.cameraOrbitAngle * Float.pi / 180.0
        let worldX = currentMoveX * cos(cameraAngleRadians) + currentMoveZ * sin(cameraAngleRadians)
        let worldZ = -currentMoveX * sin(cameraAngleRadians) + currentMoveZ * cos(cameraAngleRadians)
        
        // Only check if there's significant horizontal movement
        if abs(worldX) < 0.1 && abs(worldZ) < 0.1 {
            return (false, 0, SCNVector3(0, 1, 0))
        }
        
        // Normalize direction
        let length = sqrt(worldX * worldX + worldZ * worldZ)
        let dirX = worldX / length
        let dirZ = worldZ / length
        
        // Cast ray forward to detect walls
        let rayStartOffset: Float = 0.2
        let checkDistance: Float = 1.5
        let rayHeight: Float = 0.5
        let rayStart = SCNVector3(
            x: ballPosition.x + dirX * rayStartOffset,
            y: ballPosition.y + rayHeight,
            z: ballPosition.z + dirZ * rayStartOffset
        )
        let rayEnd = SCNVector3(
            x: ballPosition.x + dirX * (rayStartOffset + checkDistance),
            y: ballPosition.y + rayHeight,
            z: ballPosition.z + dirZ * (rayStartOffset + checkDistance)
        )
        
        let hitResults = scene.rootNode.hitTestWithSegment(from: rayStart, to: rayEnd, options: [
            SCNHitTestOption.searchMode.rawValue: SCNHitTestSearchMode.closest.rawValue,
            SCNHitTestOption.backFaceCulling.rawValue: false
        ])
        
        // Find first hit that isn't the ball
        for hit in hitResults {
            if hit.node != ballNode {
                let normal = hit.worldNormal
                
                // Check if this is a vertical wall
                let horizontalDot = sqrt(normal.x * normal.x + normal.z * normal.z)
                
                if horizontalDot > 0.7 {  // More than 45 degrees from horizontal = wall
                    let distance = sqrt(
                        pow(hit.worldCoordinates.x - ballPosition.x, 2) +
                        pow(hit.worldCoordinates.z - ballPosition.z, 2)
                    )
                    return (true, distance, normal)
                }
            }
        }
        
        return (false, 0, SCNVector3(0, 1, 0))
    }
    
    // MARK: - Vector Math Helpers
    
    private func normalize(_ v: SCNVector3) -> SCNVector3 {
        let length = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
        if length > 0.0001 {
            return SCNVector3(x: v.x / length, y: v.y / length, z: v.z / length)
        }
        return SCNVector3(0, 0, 0)
    }
    
    private func dot(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        return a.x * b.x + a.y * b.y + a.z * b.z
    }
    
    func cleanup() {
        // Nothing to clean up
    }
}
