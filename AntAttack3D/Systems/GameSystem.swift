import Foundation
import SceneKit

// MARK: - Base System Protocol
// All game systems conform to this protocol for consistent lifecycle management

protocol GameSystem: AnyObject {
    /// Reference to the game scene (weak to avoid retain cycles)
    var scene: GameScene3D? { get set }
    
    /// Called once when the system is initialized
    func setup()
    
    /// Called every frame to update the system
    /// - Parameter deltaTime: Time since last update in seconds
    func update(deltaTime: TimeInterval)
    
    /// Called when the system should clean up resources
    func cleanup()
}

// Default implementations for optional behavior
extension GameSystem {
    func setup() {}
    func cleanup() {}
}
