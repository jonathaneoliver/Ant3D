import Foundation
import CoreGraphics
import SceneKit

// MARK: - Game Constants
// Central location for all hardcoded game parameters
// NOTE: Camera/lighting parameters that can be changed via config-server
// are NOT included here. Access those via ConfigManager.shared.config

struct GameConstants {
    
    // MARK: - Movement & Controls
    struct Movement {
        static let playerSpeed: Float = 8.0             // Base player movement speed (units/sec)
        static let climbSpeed: Float = 8.0              // Vertical climbing speed (units/sec)
        static let motionSensitivity: Float = 10.0      // Tilt angle for max speed (degrees)
        static let motionUpdateRate: TimeInterval = 1.0 / 60.0  // 60 Hz motion updates
    }
    
    // MARK: - Physics
    struct Physics {
        static let gravity: Float = -98.0               // Gravity acceleration (units/sec²) - strong gravity for fast falling
        static let ballMass: Float = 1.0                // Mass of player/enemy/hostage balls
        static let ballRestitution: Float = 0.3         // Bounciness (0=no bounce, 1=perfect bounce)
        static let ballFriction: Float = 0.8            // Surface friction
        static let rollingFriction: Float = 0.3         // Rolling resistance
        static let damping: Float = 0.1                 // Linear velocity damping
        static let angularDamping: Float = 0.1          // Angular velocity damping
    }
    
    // MARK: - Enemy AI
    struct Enemy {
        static let baseSpeed: Float = 8.0               // Base movement speed (matches player)
        static let speedMultiplier: Float = 0.75        // Speed when chasing (75% of base)
        static let wanderSpeedMultiplier: Float = 0.5   // Speed when wandering (50% of chase)
        static let sightDistance: Float = 20.0          // How far enemy can see player
        static let searchTimeout: TimeInterval = 5.0    // Seconds to search before giving up
        static let wanderTargetDistance: Float = 5.0    // Distance for random wander targets
        static let wanderInterval: TimeInterval = 3.0   // Seconds between new wander targets
        static let avoidanceDistance: Float = 8.0       // Distance to avoid other enemies
    }
    
    // MARK: - Hostage Behavior
    struct Hostage {
        static let followDistance: Float = 2.0          // Stay this far behind player
        static let followSpeed: Float = 9.0             // Faster than player to catch up
        static let rescueDistance: Float = 3.0          // Distance to trigger rescue
        static let safeMatSize: Float = 4.0             // Size of safe zone at spawn
    }
    
    // MARK: - Camera System
    struct Camera {
        static let orthographicScale: Float = 20.0      // Size of orthographic view
        static let rotationAngles: [Float] = [0, 45, 90, 135, 180, 225, 270, 315]  // 8 camera angles
        static let rotationStep: Float = 45.0           // Degrees per rotation
        static let smoothingFactor: Float = 0.1         // Camera smoothing (lower = smoother)
        static let liftAboveGround: Float = 0.5         // Keep camera above ground level
        
        // NOTE: droneAngle and droneDistance are configurable via ConfigManager
    }
    
    // MARK: - Gameplay Balance
    struct Gameplay {
        static let baseHostageCount: Int = 4            // Starting hostages in level 1
        static let baseEnemyCount: Int = 2              // Starting enemies in level 1
        static let pointsPerHostage: Int = 1000         // Score for each rescue
        static let hostageIncrement: Int = 1            // Additional hostages per level
        static let enemyIncrement: Int = 1              // Additional enemies per level
        static let maxHostages: Int = 10                // Maximum hostages per level
        static let maxEnemies: Int = 8                  // Maximum enemies per level
    }
    
    // MARK: - Map Generation
    struct Map {
        static let defaultWidth: Int = 60               // Default map width (blocks)
        static let defaultHeight: Int = 60              // Default map height (blocks)
        static let maxLevels: Int = 6                   // Maximum vertical levels
        static let blockSize: Float = 1.0               // Size of each block unit
        static let wallHeight: Int = 1                  // Height of perimeter walls
        
        // Pyramid generation
        static let pyramidMinSize: Int = 6
        static let pyramidMaxSize: Int = 12
        static let towerMinHeight: Int = 4
        static let towerMaxHeight: Int = 6
        static let towerBaseSize: Int = 2
        
        // Arch dimensions
        static let archWidth: Int = 4
        static let archHeight: Int = 4
        static let archDepth: Int = 4
        static let archHoleWidth: Int = 4
        static let archHoleHeight: Int = 2
        static let archHoleDepth: Int = 2
    }
    
    // MARK: - UI Layout
    struct UI {
        // Button dimensions
        static let buttonSize: CGFloat = 50
        static let buttonPadding: CGFloat = 10
        static let buttonCornerRadius: CGFloat = 8
        static let buttonBorderWidth: CGFloat = 2
        
        // Mini-map
        static let miniMapSize: CGFloat = 120
        static let miniMapPadding: CGFloat = 10
        static let miniMapAlpha: CGFloat = 0.8
        static let miniMapBlockSize: CGFloat = 2.0
        
        // Text & Labels
        static let titleFontSize: CGFloat = 28
        static let subtitleFontSize: CGFloat = 14
        static let buttonFontSize: CGFloat = 22
        static let scoreFontSize: CGFloat = 18
        static let debugFontSize: CGFloat = 12
        
        // Spacing
        static let standardSpacing: CGFloat = 12
        static let compactSpacing: CGFloat = 6
        static let largeSpacing: CGFloat = 20
        
        // Animation
        static let buttonAnimationDuration: TimeInterval = 0.1
        static let fadeAnimationDuration: TimeInterval = 0.3
        static let pulseAnimationDuration: TimeInterval = 1.5
    }
    
    // MARK: - Material Properties
    struct Materials {
        static let lightingModel: SCNMaterial.LightingModel = .lambert
        static let specularIntensity: CGFloat = 0.6
        static let metalness: CGFloat = 0.0
        static let roughness: CGFloat = 0.8
    }
    
    // MARK: - Spawn System
    struct Spawn {
        static let playerSpawnX: Int = 5                // Player spawn position X
        static let playerSpawnY: Int = 5                // Player spawn position Y
        static let minSpawnDistance: Float = 10.0       // Min distance between spawns
        static let spawnHeightOffset: Float = 2.0       // Spawn above ground to drop
        static let maxSpawnAttempts: Int = 100          // Max attempts to find valid spawn
    }
    
    // MARK: - Collision Detection
    struct Collision {
        static let playerRadius: Float = 0.5            // Player ball radius
        static let hostageRadius: Float = 0.5           // Hostage ball radius
        static let enemyRadius: Float = 0.5             // Enemy ball radius
        static let collisionCheckDistance: Float = 1.0  // Distance for collision checks
    }
    
    // MARK: - Audio (Future Use)
    struct Audio {
        static let masterVolume: Float = 1.0
        static let musicVolume: Float = 0.7
        static let sfxVolume: Float = 0.8
    }
    
    // MARK: - Performance
    struct Performance {
        static let targetFrameRate: Int = 60
        static let physicsUpdateRate: TimeInterval = 1.0 / 60.0
        static let aiUpdateRate: TimeInterval = 1.0 / 30.0  // Update AI at 30Hz
    }
}

// MARK: - Helper Extensions
extension GameConstants {
    /// Convert degrees to radians
    static func toRadians(_ degrees: Float) -> Float {
        return degrees * .pi / 180.0
    }
    
    /// Convert radians to degrees
    static func toDegrees(_ radians: Float) -> Float {
        return radians * 180.0 / .pi
    }
    
    /// Get next camera rotation angle
    static func nextCameraAngle(current: Float) -> Float {
        guard let currentIndex = Camera.rotationAngles.firstIndex(of: current) else {
            return Camera.rotationAngles[0]
        }
        let nextIndex = (currentIndex + 1) % Camera.rotationAngles.count
        return Camera.rotationAngles[nextIndex]
    }
}
