import SceneKit
import UIKit

// State for hostage characters
enum HostageState {
    case waiting    // Waiting to be rescued
    case following  // Following player back to safe mat
    case saved      // Delivered to safe mat
}

// Hostage class - blue balls that need to be rescued
class Hostage {
    let node: SCNNode
    var state: HostageState = .waiting {
        didSet {
            if state != oldValue {
                updateColor()
                updatePhysicsType()
            }
        }
    }
    
    // Follow behavior parameters
    private let followDistance: Float = GameConstants.Hostage.followDistance
    private let followSpeed: Float = GameConstants.Hostage.followSpeed
    private var targetPosition: SCNVector3?  // Where to move toward
    
    init(position: SCNVector3) {
        // Create sphere geometry (same size as player ball)
        let sphere = SCNSphere(radius: CGFloat(GameConstants.Collision.hostageRadius))
        
        // Blue material for hostage
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.blue
        material.lightingModel = .lambert
        material.specular.contents = UIColor(white: 0.6, alpha: 1.0)
        sphere.materials = [material]
        
        // Create node
        node = SCNNode(geometry: sphere)
        node.name = "Hostage"
        node.position = position
        
        // Add physics body (dynamic by default so hostages fall onto blocks)
        let physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: sphere))  // Using GameConstants for physics
        physicsBody.mass = CGFloat(GameConstants.Physics.ballMass)
        physicsBody.restitution = CGFloat(GameConstants.Physics.ballRestitution)
        physicsBody.friction = CGFloat(GameConstants.Physics.ballFriction)
        physicsBody.rollingFriction = CGFloat(GameConstants.Physics.rollingFriction)
        physicsBody.damping = CGFloat(GameConstants.Physics.damping)
        physicsBody.angularDamping = CGFloat(GameConstants.Physics.angularDamping)
        
        node.physicsBody = physicsBody
    }
    
    // Update hostage color based on current state
    private func updateColor() {
        guard let material = node.geometry?.firstMaterial else { return }
        
        // Animate color change for smooth transitions
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.3
        
        switch state {
        case .waiting:
            // Blue = Waiting to be rescued
            material.diffuse.contents = UIColor.blue
        case .following:
            // Cyan = Following player
            material.diffuse.contents = UIColor.cyan
        case .saved:
            // Green = Successfully saved
            material.diffuse.contents = UIColor.green
        }
        
        SCNTransaction.commit()
    }
    
    // Update physics body type based on state
    private func updatePhysicsType() {
        guard let physicsBody = node.physicsBody else { return }
        
        switch state {
        case .waiting:
            // Dynamic = affected by gravity, will fall onto blocks and stay there
            // This ensures hostages properly rest on the blocks they're spawned above
            physicsBody.type = .dynamic
        case .following:
            // Dynamic = affected by gravity, can move
            physicsBody.type = .dynamic
        case .saved:
            // Kinematic = stays in place on safe mat
            physicsBody.type = .kinematic
        }
    }
    
    // Update hostage behavior (called every frame when following)
    func update(playerPosition: SCNVector3) {
        guard state == .following else { return }
        guard let physicsBody = node.physicsBody else { return }
        
        let currentPosition = node.presentation.position
        
        // Calculate distance to player
        let dx = playerPosition.x - currentPosition.x
        let dz = playerPosition.z - currentPosition.z
        let distanceToPlayer = sqrt(dx*dx + dz*dz)
        
        // If too far from player, move toward them
        if distanceToPlayer > followDistance {
            // Calculate direction to player
            let direction = SCNVector3(
                x: playerPosition.x - currentPosition.x,
                y: 0,  // No vertical movement (can't climb without player help)
                z: playerPosition.z - currentPosition.z
            )
            
            // Normalize direction
            let length = sqrt(direction.x * direction.x + direction.z * direction.z)
            if length > 0.1 {
                let normalized = SCNVector3(x: direction.x / length, y: 0, z: direction.z / length)
                
                // Apply velocity to move toward player
                physicsBody.velocity.x = normalized.x * followSpeed
                physicsBody.velocity.z = normalized.z * followSpeed
                // Don't touch Y velocity - let gravity handle it
            }
        } else {
            // Close enough - slow down
            physicsBody.velocity.x *= 0.9
            physicsBody.velocity.z *= 0.9
        }
    }
}
