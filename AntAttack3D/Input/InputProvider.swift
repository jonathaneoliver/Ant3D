import Foundation
import SceneKit

/// Helper struct for 2D input vector
struct InputVector {
    var x: Float
    var z: Float
    
    static let zero = InputVector(x: 0, z: 0)
    
    var magnitude: Float {
        return sqrt(x * x + z * z)
    }
    
    func normalized() -> InputVector {
        let mag = magnitude
        if mag > 0.0001 {
            return InputVector(x: x / mag, z: z / mag)
        }
        return .zero
    }
}

/// Protocol for input providers (controller, motion, touch, etc.)
protocol InputProvider: AnyObject {
    /// Current movement vector (-1 to 1 for X and Z)
    var moveVector: InputVector { get }
    
    /// Whether the climb/jump button is pressed
    var isClimbPressed: Bool { get }
    
    /// Whether this input provider is currently active
    var isActive: Bool { get }
    
    /// Priority level (higher = preferred when multiple inputs active)
    var priority: Int { get }
    
    /// Setup the input provider
    func setup()
    
    /// Update the input provider (called every frame)
    func update()
    
    /// Clean up resources
    func cleanup()
}
