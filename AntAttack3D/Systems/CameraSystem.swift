import Foundation
import SceneKit
import UIKit
import os.log

private let logger = Logger(subsystem: "com.example.AntAttack3D", category: "CameraSystem")

/// Manages camera positioning, movement, visibility checking, and orbit search behavior
class CameraSystem: GameSystem {
    weak var scene: GameScene3D?
    
    // MARK: - Camera Configuration
    var droneAngle: Float = 45.0        // Down angle in degrees (10-90)
    var droneDistance: Float = 30.0     // Distance from ball
    var orbitSearchDelay: Float = 2.0   // Seconds to wait before orbit search
    
    // MARK: - Camera State
    var cameraOrbitAngle: Float = 0.0   // Horizontal angle around ball (0-360 degrees)
    private var isSearchingForBall: Bool = false
    private var framesInCurrentOrbitPosition: Int = 0
    private let framesBeforeNextOrbit = 45      // Wait 0.75 seconds at each position (at 60fps)
    private let orbitStepDegrees: Float = 90.0  // Rotate 90 degrees each step
    private var orbitSearchStartAngle: Float = 0.0
    private var hasCompletedFullRotation: Bool = false
    private var hiddenDuration: Float = 0.0     // How long ball has been hidden (seconds)
    
    // MARK: - Visibility Tracking
    private var lastVisibilityState: Bool = true
    private var visibleFrameCount: Int = 0      // Consecutive frames ball was visible
    private var hiddenFrameCount: Int = 0       // Consecutive frames ball was hidden
    private let visibilityChangeThreshold = 5   // Need 5 consecutive frames to change state
    private var visibilityCheckFrameCount: Int = 0
    private var forceImmediateCameraUpdate: Bool = false
    
    // MARK: - Debug Counters
    private var updateCameraFrameCount = 0
    private var visibilityRaycastCount = 0
    private var distanceUpdateCount = 0
    
    // MARK: - Callbacks
    var onBallVisibilityChanged: ((Bool) -> Void)?
    var onDistanceChanged: ((Float) -> Void)?
    
    init() {}
    
    func setup() {
        // Initialize orbit angle to match camera's starting position (south of center, positive Z)
        cameraOrbitAngle = 0.0
        
        // Send initial visibility state
        onBallVisibilityChanged?(true)
    }
    
    /// Update camera position to follow ball and check visibility
    func update(deltaTime: TimeInterval) {
        guard let scene = scene else { return }
        guard let cameraNode = scene.cameraNode else { return }
        guard let ballNode = scene.ballNode else { return }
        guard let sceneView = scene.sceneView else { return }
        
        updateCameraFrameCount += 1
        
        // Use presentation node to get actual rendered position during physics simulation
        let ballPosition = ballNode.presentation.position
        
        // Log ball position periodically
        if updateCameraFrameCount % 60 == 0 {  // Log every second at 60fps
            if let velocity = ballNode.physicsBody?.velocity {
                logger.debug("Ball: pos=(\(ballPosition.x), \(ballPosition.y), \(ballPosition.z)) vel=(\(velocity.x), \(velocity.y), \(velocity.z))")
            }
        }
        
        // Calculate camera position
        let angleRadians = droneAngle * Float.pi / 180.0
        let cameraHeight = droneDistance * sin(angleRadians)
        let horizontalOffset = droneDistance * cos(angleRadians)
        
        // Handle orbit search logic
        updateOrbitSearch()
        
        // Calculate target position using current orbit angle
        let orbitRadians = cameraOrbitAngle * Float.pi / 180.0
        let targetCameraX = ballPosition.x + horizontalOffset * sin(orbitRadians)
        let targetCameraZ = ballPosition.z + horizontalOffset * cos(orbitRadians)
        let targetCameraY = ballPosition.y + cameraHeight
        let targetPosition = SCNVector3(x: targetCameraX, y: targetCameraY, z: targetCameraZ)
        
        // Smooth camera movement
        let smoothingXZ: Float = forceImmediateCameraUpdate ? 1.0 : (isSearchingForBall ? 0.25 : 0.3)
        let smoothingY: Float = forceImmediateCameraUpdate ? 1.0 : 0.2
        
        cameraNode.position.x += (targetPosition.x - cameraNode.position.x) * smoothingXZ
        cameraNode.position.y += (targetPosition.y - cameraNode.position.y) * smoothingY
        cameraNode.position.z += (targetPosition.z - cameraNode.position.z) * smoothingXZ
        
        // Clear force update flag
        if forceImmediateCameraUpdate {
            forceImmediateCameraUpdate = false
            sceneView.setNeedsDisplay()
        }
        
        // Calculate actual distance from camera to ball
        let dx = cameraNode.position.x - ballPosition.x
        let dy = cameraNode.position.y - ballPosition.y
        let dz = cameraNode.position.z - ballPosition.z
        let actualDistance = sqrt(dx*dx + dy*dy + dz*dz)
        
        // Report distance to HUD
        distanceUpdateCount += 1
        if distanceUpdateCount % 60 == 0 {
            logger.debug("Distance: \(actualDistance)")
        }
        onDistanceChanged?(actualDistance)
        
        // Check visibility and update state
        updateVisibility(cameraNode: cameraNode, ballPosition: ballPosition, sceneView: sceneView)
        
        // Look directly at the ball with horizon stabilization
        cameraNode.look(at: ballPosition, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
        
        // Update directional light to follow ball
        if let lightNode = scene.directionalLightNode {
            lightNode.position = SCNVector3(x: ballPosition.x, y: 80.0, z: ballPosition.z)
            lightNode.look(at: ballPosition)
        }
    }
    
    /// Handle orbit search behavior when ball is hidden
    private func updateOrbitSearch() {
        if isSearchingForBall {
            if hasCompletedFullRotation {
                // Ball is completely occluded, stop searching
                return
            }
            
            // Increment frame counter and rotate to next position when ready
            framesInCurrentOrbitPosition += 1
            
            if framesInCurrentOrbitPosition >= framesBeforeNextOrbit {
                cameraOrbitAngle += orbitStepDegrees
                if cameraOrbitAngle >= 360.0 {
                    cameraOrbitAngle = 0.0
                }
                framesInCurrentOrbitPosition = 0
                
                // Check if we've completed a full 360° rotation
                let totalRotation = cameraOrbitAngle - orbitSearchStartAngle
                let normalizedRotation = totalRotation < 0 ? totalRotation + 360.0 : totalRotation
                
                if normalizedRotation >= 360.0 || (normalizedRotation >= 0 && normalizedRotation < orbitStepDegrees && cameraOrbitAngle != orbitSearchStartAngle) {
                    hasCompletedFullRotation = true
                }
            }
        }
    }
    
    /// Check ball visibility and update state machine
    private func updateVisibility(cameraNode: SCNNode, ballPosition: SCNVector3, sceneView: SCNView) {
        // OPTIMIZATION: Only check every 3 frames to reduce raycast overhead
        visibilityCheckFrameCount += 1
        let shouldCheckVisibility = (visibilityCheckFrameCount % 3 == 0)
        
        if shouldCheckVisibility {
            let currentFrameVisible = isBallVisibleFromPosition(cameraNode.position, ballPosition: ballPosition, sceneView: sceneView)
            
            // Apply temporal smoothing - require multiple consecutive frames
            if currentFrameVisible {
                visibleFrameCount += 1
                hiddenFrameCount = 0
            } else {
                hiddenFrameCount += 1
                visibleFrameCount = 0
            }
        }
        
        // Determine smoothed visibility state
        var isVisible = lastVisibilityState
        
        if lastVisibilityState && hiddenFrameCount >= visibilityChangeThreshold {
            isVisible = false
        } else if !lastVisibilityState && visibleFrameCount >= visibilityChangeThreshold {
            isVisible = true
        }
        
        // Update HUD and handle transitions
        if isVisible != lastVisibilityState {
            lastVisibilityState = isVisible
            onBallVisibilityChanged?(isVisible)
            logger.debug("Ball visibility: \(isVisible ? "visible" : "hidden")")
            
            // Handle search mode transitions
            if !isVisible && !isSearchingForBall {
                hiddenDuration = 0.0
            } else if isVisible && isSearchingForBall {
                isSearchingForBall = false
                framesInCurrentOrbitPosition = 0
                hasCompletedFullRotation = false
                hiddenDuration = 0.0
            } else if isVisible {
                hiddenDuration = 0.0
            }
        }
        
        // Accumulate hidden duration and start orbit search after delay
        if !lastVisibilityState && !isSearchingForBall {
            hiddenDuration += 1.0 / 60.0  // Assume 60fps
            
            if hiddenDuration >= orbitSearchDelay {
                guard let scene = scene, let ballNode = scene.ballNode else { return }
                let ballPos = ballNode.presentation.position
                
                isSearchingForBall = true
                framesInCurrentOrbitPosition = 0
                hasCompletedFullRotation = false
                
                // Initialize orbit angle to current camera angle
                let currentDx = cameraNode.position.x - ballPos.x
                let currentDz = cameraNode.position.z - ballPos.z
                cameraOrbitAngle = atan2(currentDx, currentDz) * 180.0 / Float.pi
                if cameraOrbitAngle < 0 { cameraOrbitAngle += 360.0 }
                orbitSearchStartAngle = cameraOrbitAngle
            }
        }
    }
    
    /// Check if ball is visible from camera position using screen-space hit testing
    private func isBallVisibleFromPosition(_ cameraPos: SCNVector3, ballPosition: SCNVector3, sceneView: SCNView) -> Bool {
        guard let scene = scene, let ballNode = scene.ballNode else { return true }
        
        visibilityRaycastCount += 1
        let shouldLog = (visibilityRaycastCount % 300 == 0)
        
        // Project 3D ball position to 2D screen coordinates
        let ballScreenPos = sceneView.projectPoint(ballPosition)
        let screenPoint = CGPoint(x: CGFloat(ballScreenPos.x), y: CGFloat(ballScreenPos.y))
        
        // Check if screen point is within view bounds
        guard sceneView.bounds.contains(screenPoint) else {
            return false
        }
        
        // Hit test at the ball's screen position
        let hitOptions: [SCNHitTestOption: Any] = [
            .searchMode: SCNHitTestSearchMode.closest.rawValue as NSNumber,
            .ignoreHiddenNodes: true as NSNumber
        ]
        
        let hits = sceneView.hitTest(screenPoint, options: hitOptions)
        
        if hits.isEmpty {
            return false
        }
        
        // Check if the first hit is the ball
        if let firstHit = hits.first {
            let isBall = (firstHit.node == ballNode)
            
            // Also check distance - if hit is very close to ball distance, consider it visible
            let hitDistance = sqrt(
                pow(firstHit.worldCoordinates.x - cameraPos.x, 2) +
                pow(firstHit.worldCoordinates.y - cameraPos.y, 2) +
                pow(firstHit.worldCoordinates.z - cameraPos.z, 2)
            )
            let ballDistance = sqrt(
                pow(ballPosition.x - cameraPos.x, 2) +
                pow(ballPosition.y - cameraPos.y, 2) +
                pow(ballPosition.z - cameraPos.z, 2)
            )
            let distanceDiff = abs(hitDistance - ballDistance)
            let isNearBall = distanceDiff < 1.0
            
            if shouldLog {
                logger.debug("Visibility check: isBall=\(isBall), isNearBall=\(isNearBall), distDiff=\(distanceDiff)")
            }
            
            return isBall || isNearBall
        }
        
        return false
    }
    
    /// Update camera configuration (called when config changes)
    func updateConfig(droneAngle: Float, droneDistance: Float, orbitSearchDelay: Float) {
        let angleChanged = self.droneAngle != droneAngle
        let distanceChanged = self.droneDistance != droneDistance
        
        self.droneAngle = droneAngle
        self.droneDistance = droneDistance
        self.orbitSearchDelay = orbitSearchDelay
        
        if angleChanged || distanceChanged {
            self.forceImmediateCameraUpdate = true
        }
    }
    
    /// Update camera position for map size (called when map loads)
    func updateCameraForMapSize(cityMap: CityMap3D) {
        guard let scene = scene else { return }
        guard let cameraNode = scene.cameraNode else { return }
        
        let centerX = Float(cityMap.width) / 2.0
        let centerZ = Float(cityMap.height) / 2.0
        
        if let ballNode = scene.ballNode {
            // If ball exists, updateCamera will handle it
            return
        } else {
            // No ball yet, just center the camera
            cameraNode.position = SCNVector3(x: centerX, y: 15, z: centerZ + 30)
            cameraNode.look(at: SCNVector3(x: centerX, y: 10, z: centerZ))
        }
    }
    
    /// Rotate camera by 45 degrees around the ball (manual control)
    func rotateCameraView() {
        cameraOrbitAngle += 45.0
        
        if cameraOrbitAngle >= 360.0 {
            cameraOrbitAngle -= 360.0
        }
        
        logger.info("Camera rotated to \(self.cameraOrbitAngle)°")
    }
    
    func cleanup() {
        // Nothing to clean up currently
    }
}
