import SceneKit
import UIKit
import os.log

class GameScene3D: SCNScene {
    
    var cityMap: CityMap3D!
    var cameraNode: SCNNode!
    var blockNodes: [SCNNode] = []
    var ballNode: SCNNode!
    var directionalLightNode: SCNNode!  // Track the light so we can move it
    var ambientLightNode: SCNNode!      // Track ambient light to adjust intensity
    weak var sceneView: SCNView?        // Reference to the view for hit testing
    
    // Camera follow configuration (updated by config server)
    var droneAngle: Float = 45.0        // Down angle in degrees (10-90)
    var droneDistance: Float = 30.0     // Distance from ball
    var ambientLightIntensity: Float = 0.5
    var shadowsEnabled: Bool = false
    
    // Controller input state
    private var currentMoveX: Float = 0.0
    private var currentMoveZ: Float = 0.0
    
    // Ball visibility callback
    var onBallVisibilityChanged: ((Bool) -> Void)?
    var onDistanceChanged: ((Float) -> Void)?
    private var lastVisibilityState: Bool = true
    private var visibilityCheckFrameCount: Int = 0
    
    // Visibility smoothing - require multiple consecutive frames before changing state
    private var visibleFrameCount: Int = 0      // Consecutive frames ball was visible
    private var hiddenFrameCount: Int = 0       // Consecutive frames ball was hidden
    private let visibilityChangeThreshold = 5   // Need 5 consecutive frames to change state
    
    // Camera orbit state for searching when ball is hidden
    private var cameraOrbitAngle: Float = 0.0   // Horizontal angle around ball (0-360 degrees)
    private var isSearchingForBall: Bool = false
    private var framesInCurrentOrbitPosition: Int = 0
    private let framesBeforeNextOrbit = 30      // Wait 0.5 seconds at each position (at 60fps)
    private let orbitStepDegrees: Float = 45.0  // Rotate 45 degrees each step
    
    // Debug counters
    private var updateCameraFrameCount = 0
    private var visibilityRaycastCount = 0
    private var distanceUpdateCount = 0
    
    override init() {
        super.init()
        print("========================================")
        print("🏙️  GameScene3D init() called")
        print("========================================")
        NSLog("🏙️  GameScene3D init() called")
        os_log("🏙️  GameScene3D init() called", type: .error)
        setupScene()
        setupConfigListener()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupScene()
        setupConfigListener()
    }
    
    func setupConfigListener() {
        // Listen for config updates
        ConfigManager.shared.onConfigUpdate = { [weak self] config in
            print("GameScene3D: Received config update - angle: \(config.droneAngle)°, distance: \(config.droneDistance), ambient: \(config.ambientLight), shadows: \(config.shadowsEnabled)")
            self?.droneAngle = config.droneAngle
            self?.droneDistance = config.droneDistance
            self?.updateAmbientLight(config.ambientLight)
            self?.updateShadows(config.shadowsEnabled)
        }
    }
    
    func setupScene() {
        print("========================================")
        print("🏗️  GameScene setupScene started")
        print("========================================")
        NSLog("🏗️  GameScene setupScene started")
        os_log("🏗️  GameScene setupScene started", type: .error)
        
        // Set background color (light cyan like the Python sample)
        background.contents = UIColor(red: 0.59, green: 0.85, blue: 0.93, alpha: 1.0)
        
        // Create city map (60x60 larger map with many arches)
        cityMap = CityMap3D(width: 60, height: 60)
        print("CityMap created")
        
        // Setup camera
        setupCamera()
        print("Camera setup complete")
        
        // Setup lighting
        setupLighting()
        print("Lighting setup complete")
        
        // Render the city
        renderCity()
        print("City rendered - \(blockNodes.count) blocks created")
        
        // Add axis labels
        addAxisLabels()
        print("Axis labels added")
        
        // Create the ball
        createBall()
        print("Ball created")
        
        // Send initial visibility state to HUD
        onBallVisibilityChanged?(true)
        print("🎯 Initial ball visibility set to: VISIBLE ✅")
    }
    
    func setupCamera() {
        // Create camera node
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        
        // Use perspective projection for more natural level ground view
        cameraNode.camera?.usesOrthographicProjection = false
        cameraNode.camera?.fieldOfView = 60.0  // Standard field of view
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 200.0
        
        // Position camera for level ground view (looking horizontally at the scene)
        // Adjust for larger 60x60 map (center is at 30, 30)
        let centerX = Float(cityMap.width) / 2.0
        let centerZ = Float(cityMap.height) / 2.0
        
        // Camera behind and slightly above the ball for level ground view
        cameraNode.position = SCNVector3(x: centerX, y: 15, z: centerZ + 30)
        cameraNode.look(at: SCNVector3(x: centerX, y: 10, z: centerZ))
        
        rootNode.addChildNode(cameraNode)
    }
    
    func setupLighting() {
        // Ambient light for overall illumination
        ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light?.type = .ambient
        ambientLightNode.light?.color = UIColor(white: CGFloat(ambientLightIntensity), alpha: 1.0)
        rootNode.addChildNode(ambientLightNode)
        
        // Directional light for depth (shadows disabled)
        directionalLightNode = SCNNode()
        directionalLightNode.light = SCNLight()
        directionalLightNode.light?.type = .directional
        directionalLightNode.light?.color = UIColor(white: 0.7, alpha: 1.0)
        directionalLightNode.light?.castsShadow = false  // Shadows disabled
        
        // Position light above center of larger map (will be updated to follow ball)
        let centerX = Float(cityMap.width) / 2.0
        let centerZ = Float(cityMap.height) / 2.0
        directionalLightNode.position = SCNVector3(x: centerX, y: 80, z: centerZ)
        directionalLightNode.look(at: SCNVector3(x: centerX, y: 0, z: centerZ))
        
        rootNode.addChildNode(directionalLightNode)
    }
    
    func renderCity() {
        // Clear existing blocks
        blockNodes.forEach { $0.removeFromParentNode() }
        blockNodes.removeAll()
        
        // Create flat sand-colored ground
        createGround()
        
        // Create blocks for all positions that have blocks in the map
        for x in 0..<cityMap.width {
            for y in 0..<cityMap.height {
                for z in 0..<cityMap.maxLevels {
                    if cityMap.hasBlock(x: x, y: y, z: z) {
                        createBlock(x: x, y: y, z: z)
                    }
                }
            }
        }
        
        // Create ramps (wedge-shaped blocks)
        for ramp in cityMap.ramps {
            createRamp(ramp: ramp)
        }
    }
    
    func createGround() {
        // Create a very large flat box for the ground to extend to infinity
        // Make it 10x the size of the map to appear infinite
        let infiniteSize: CGFloat = CGFloat(max(cityMap.width, cityMap.height)) * 10.0
        let groundBox = SCNBox(width: infiniteSize, height: 0.1, length: infiniteSize, chamferRadius: 0.0)
        
        // Sand color material
        let groundMaterial = SCNMaterial()
        groundMaterial.diffuse.contents = UIColor(red: 0.87, green: 0.72, blue: 0.53, alpha: 1.0)  // Sand color
        groundMaterial.lightingModel = .lambert
        groundMaterial.isDoubleSided = false  // Only render top side
        
        // Apply same material to all faces for consistent appearance
        groundBox.materials = [groundMaterial, groundMaterial, groundMaterial, groundMaterial, groundMaterial, groundMaterial]
        
        // Create node and position it
        let groundNode = SCNNode(geometry: groundBox)
        
        // Position the ground slightly below y=0 to avoid z-fighting with blocks
        // Center is at half-height of box
        groundNode.position = SCNVector3(
            x: Float(cityMap.width) / 2.0 - 0.5,
            y: -0.55,  // Half of box height (0.1/2) below ground level
            z: Float(cityMap.height) / 2.0 - 0.5
        )
        
        rootNode.addChildNode(groundNode)
        blockNodes.append(groundNode)
        
        // Add static physics body to ground
        groundNode.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: groundBox))
        groundNode.physicsBody?.restitution = 0.1
        groundNode.physicsBody?.friction = 0.8
    }
    
    func createBlock(x: Int, y: Int, z: Int) {
        // Create a box geometry (1x1x1 unit cube)
        let box = SCNBox(width: 1.0, height: 1.0, length: 1.0, chamferRadius: 0.0)
        
        // Create materials for each face
        let materials = createBlockMaterials(z: z)
        box.materials = materials
        
        // Create node and position it
        let blockNode = SCNNode(geometry: box)
        
        // Shadow casting disabled
        blockNode.castsShadow = false
        
        // Position: x goes right, y goes up, z goes forward
        // We want y to be height, so blocks stack vertically
        blockNode.position = SCNVector3(
            x: Float(x),
            y: Float(z) + 0.5,  // +0.5 because box center is at its middle
            z: Float(y)
        )
        
        // Add static physics body to block
        blockNode.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: box))
        blockNode.physicsBody?.restitution = 0.1
        blockNode.physicsBody?.friction = 0.8
        
        rootNode.addChildNode(blockNode)
        blockNodes.append(blockNode)
    }
    
    func createRamp(ramp: Ramp) {
        // Create a wedge-shaped ramp geometry
        // Normal ramps: 1x1x1 in size (1 forward for 1 up)
        // Shallow ramps: 2x1x1 in size (2 forward for 1 up) - half the steepness
        // Wedge slopes UP from front to back (low edge at -Z, high edge at +Z)
        // direction: 0=south (+y), 1=west (-x), 2=north (-y), 3=east (+x)
        
        let depth: Float = ramp.isShallow ? 2.0 : 1.0  // Shallow ramps are twice as deep
        let halfDepth = depth / 2.0
        
        // Define vertices for a wedge shape (triangular prism)
        // Low edge is at front (-Z), high edge is at back (+Z)
        let vertices: [SCNVector3] = [
            // Bottom face (4 vertices forming a rectangle)
            SCNVector3(-0.5, -0.5, -halfDepth),  // 0: bottom-left-front (LOW EDGE)
            SCNVector3(0.5, -0.5, -halfDepth),   // 1: bottom-right-front (LOW EDGE)
            SCNVector3(0.5, -0.5, halfDepth),    // 2: bottom-right-back
            SCNVector3(-0.5, -0.5, halfDepth),   // 3: bottom-left-back
            
            // Top edge (2 vertices - the high edge of the wedge at the back)
            SCNVector3(-0.5, 0.5, halfDepth),    // 4: top-left-back (HIGH EDGE)
            SCNVector3(0.5, 0.5, halfDepth),     // 5: top-right-back (HIGH EDGE)
        ]
        
        let vertexData = Data(bytes: vertices, count: vertices.count * MemoryLayout<SCNVector3>.size)
        let vertexSource = SCNGeometrySource(data: vertexData,
                                            semantic: .vertex,
                                            vectorCount: vertices.count,
                                            usesFloatComponents: true,
                                            componentsPerVector: 3,
                                            bytesPerComponent: MemoryLayout<Float>.size,
                                            dataOffset: 0,
                                            dataStride: MemoryLayout<SCNVector3>.size)
        
        // Define UV coordinates for texture mapping
        // Map the sloped face to show the stairs texture
        // For shallow ramps, the V coordinate should stretch to maintain step appearance
        let uvCoordinates: [CGPoint] = [
            CGPoint(x: 0, y: 0),  // 0: bottom-left-front
            CGPoint(x: 1, y: 0),  // 1: bottom-right-front
            CGPoint(x: 1, y: 1),  // 2: bottom-right-back
            CGPoint(x: 0, y: 1),  // 3: bottom-left-back
            CGPoint(x: 0, y: 1),  // 4: top-left-back
            CGPoint(x: 1, y: 1),  // 5: top-right-back
        ]
        
        let uvData = Data(bytes: uvCoordinates, count: uvCoordinates.count * MemoryLayout<CGPoint>.size)
        let uvSource = SCNGeometrySource(data: uvData,
                                        semantic: .texcoord,
                                        vectorCount: uvCoordinates.count,
                                        usesFloatComponents: true,
                                        componentsPerVector: 2,
                                        bytesPerComponent: MemoryLayout<CGFloat>.size,
                                        dataOffset: 0,
                                        dataStride: MemoryLayout<CGPoint>.size)
        
        // Define faces using indices
        // Each triangle is defined by 3 indices
        let indices: [Int32] = [
            // Bottom face (2 triangles)
            0, 2, 1,
            0, 3, 2,
            
            // Sloped face (2 triangles)
            0, 1, 5,
            0, 5, 4,
            
            // Left face (triangle)
            0, 4, 3,
            
            // Right face (triangle)
            1, 2, 5,
            
            // Back face (rectangle, 2 triangles)
            3, 4, 5,
            3, 5, 2,
        ]
        
        let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<Int32>.size)
        let element = SCNGeometryElement(data: indexData,
                                        primitiveType: .triangles,
                                        primitiveCount: indices.count / 3,
                                        bytesPerIndex: MemoryLayout<Int32>.size)
        
        // Create geometry
        let rampGeometry = SCNGeometry(sources: [vertexSource, uvSource], elements: [element])
        
        // Apply grey materials (same as elevated blocks)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1.0)  // Light grey
        material.lightingModel = .lambert
        material.isDoubleSided = true  // Render both sides for wedge
        
        // Add normal map to create stairs effect
        material.normal.contents = createStairsNormalMap()
        material.normal.intensity = 2.0  // Higher value for more pronounced effect
        
        rampGeometry.materials = [material]
        
        // Create node
        let rampNode = SCNNode(geometry: rampGeometry)
        // Shadow casting disabled
        rampNode.castsShadow = false
        
        // Position and rotate based on direction
        // Base position (centered on block position)
        // For shallow ramps, we need to offset by 0.5 blocks in the direction the ramp extends
        var xOffset: Float = 0
        var zOffset: Float = 0
        
        if ramp.isShallow {
            // Shallow ramps extend 2 blocks, so offset by 0.5 blocks from base position
            switch ramp.direction {
            case 0:  // South wall - extends in +z direction
                zOffset = 0.5
            case 1:  // West wall - extends in +x direction  
                xOffset = 0.5
            case 2:  // North wall - extends in -z direction
                zOffset = -0.5
            case 3:  // East wall - extends in -x direction
                xOffset = -0.5
            default:
                break
            }
        }
        
        rampNode.position = SCNVector3(
            x: Float(ramp.x) + xOffset,
            y: Float(ramp.z) + 0.5,  // Same as blocks
            z: Float(ramp.y) + zOffset
        )
        
        // Rotate based on which wall the ramp is on
        // Default wedge orientation: low edge at -Z (front), high edge at +Z (back)
        // Map coordinates: x=right, y=forward in map -> x=right, z=forward in scene
        // 
        // If ramp is on NORTH wall: tall edge points SOUTH (toward pyramid)
        // If ramp is on SOUTH wall: tall edge points NORTH (toward pyramid)
        // If ramp is on EAST wall: tall edge points WEST (toward pyramid)
        // If ramp is on WEST wall: tall edge points EAST (toward pyramid)
        //
        // direction: 0=south wall, 1=west wall, 2=north wall, 3=east wall
        // Map Y -> Scene Z, Map X -> Scene X
        // 
        // 0 = south wall: tall edge points NORTH (-z), rotate 180°
        // 1 = west wall: tall edge points EAST (+x), rotate +90° (was -90°, flipped 180°)
        // 2 = north wall: tall edge points SOUTH (+z), rotate 0°
        // 3 = east wall: tall edge points WEST (-x), rotate -90° (was +90°, flipped 180°)
        switch ramp.direction {
        case 0:  // South wall - tall edge points north (toward pyramid center)
            rampNode.eulerAngles.y = Float.pi
        case 1:  // West wall - tall edge points east (toward pyramid center)
            rampNode.eulerAngles.y = Float.pi / 2
        case 2:  // North wall - tall edge points south (toward pyramid center)
            rampNode.eulerAngles.y = 0
        case 3:  // East wall - tall edge points west (toward pyramid center)
            rampNode.eulerAngles.y = -Float.pi / 2
        default:
            break
        }
        
        // Add static physics body to ramp
        rampNode.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: rampGeometry))
        rampNode.physicsBody?.restitution = 0.1
        rampNode.physicsBody?.friction = 0.8
        
        rootNode.addChildNode(rampNode)
        blockNodes.append(rampNode)
    }
    
    // Create a procedural normal map texture for stairs effect on ramps
    func createStairsNormalMap() -> UIImage {
        let size = 512  // Higher resolution for better quality
        let stepsCount = 10  // Number of visible steps
        let stepHeight = size / stepsCount
        
        // Create image context
        UIGraphicsBeginImageContextWithOptions(CGSize(width: size, height: size), true, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return UIImage()
        }
        
        // Fill with neutral normal (pointing straight out = RGB(128, 128, 255) for normal maps)
        context.setFillColor(UIColor(red: 0.5, green: 0.5, blue: 1.0, alpha: 1.0).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        
        // Draw step edges as normal map variations
        // Normal maps encode surface direction in RGB:
        // R = X direction (red = right, cyan = left)
        // G = Y direction (green = up, magenta = down)  
        // B = Z direction (blue = out toward camera)
        // Neutral normal pointing "out" = RGB(0.5, 0.5, 1.0) or (128, 128, 255) in 8-bit
        
        for step in 0..<stepsCount {
            let y = CGFloat(step * stepHeight)
            let edgeHeight: CGFloat = 6  // Height of the step edge highlight
            
            // Step tread (flat part) - normal pointing up and out (more green = up)
            context.setFillColor(UIColor(red: 0.5, green: 0.65, blue: 0.9, alpha: 1.0).cgColor)
            context.fill(CGRect(x: 0, y: y, width: CGFloat(size), height: CGFloat(stepHeight - Int(edgeHeight))))
            
            // Step riser (vertical edge) - normal pointing forward and down (less green, less blue)
            context.setFillColor(UIColor(red: 0.5, green: 0.35, blue: 0.7, alpha: 1.0).cgColor)
            context.fill(CGRect(x: 0, y: y + CGFloat(stepHeight) - edgeHeight, width: CGFloat(size), height: edgeHeight))
        }
        
        let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        
        return image
    }
    
    func createBlockMaterials(z: Int) -> [SCNMaterial] {
        // Create 6 materials (one for each face of the cube)
        // Order: front, right, back, left, top, bottom
        
        var materials: [SCNMaterial] = []
        
        // All blocks use shades of grey
        // Wall blocks (z == 0) use medium grey, elevated blocks use lighter grey
        let isWall = (z == 0)
        
        // Top face
        let topMaterial = SCNMaterial()
        topMaterial.diffuse.contents = isWall ?
            UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0) :  // Medium gray for walls
            UIColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1.0) // Light gray for elevated blocks
        topMaterial.lightingModel = .lambert
        
        // Side faces (darker shades)
        let sideMaterial1 = SCNMaterial()
        sideMaterial1.diffuse.contents = isWall ?
            UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0) :
            UIColor(red: 0.65, green: 0.65, blue: 0.65, alpha: 1.0)
        sideMaterial1.lightingModel = .lambert
        
        let sideMaterial2 = SCNMaterial()
        sideMaterial2.diffuse.contents = isWall ?
            UIColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1.0) :
            UIColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1.0)
        sideMaterial2.lightingModel = .lambert
        
        let bottomMaterial = SCNMaterial()
        bottomMaterial.diffuse.contents = isWall ?
            UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0) :
            UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        bottomMaterial.lightingModel = .lambert
        
        // Assign materials: front, right, back, left, top, bottom
        materials.append(sideMaterial1)  // front
        materials.append(sideMaterial2)  // right
        materials.append(sideMaterial1)  // back
        materials.append(sideMaterial2)  // left
        materials.append(topMaterial)    // top
        materials.append(bottomMaterial) // bottom
        
        return materials
    }
    
    func addAxisLabels() {
        // Create axis lines and labels at the origin
        // X-axis (red) - points to the right
        addAxisLine(from: SCNVector3(0, 0, 0), to: SCNVector3(3, 0, 0), color: .red)
        addAxisLabel(text: "X", position: SCNVector3(3.5, 0, 0), color: .red)
        
        // Y-axis (green) - points up (but in our coordinate system, this is Z - height)
        addAxisLine(from: SCNVector3(0, 0, 0), to: SCNVector3(0, 3, 0), color: .green)
        addAxisLabel(text: "Y", position: SCNVector3(0, 3.5, 0), color: .green)
        
        // Z-axis (blue) - points forward
        addAxisLine(from: SCNVector3(0, 0, 0), to: SCNVector3(0, 0, 3), color: .blue)
        addAxisLabel(text: "Z", position: SCNVector3(0, 0, 3.5), color: .blue)
        
        // Add a small sphere at the origin
        let originSphere = SCNSphere(radius: 0.15)
        originSphere.firstMaterial?.diffuse.contents = UIColor.yellow
        let originNode = SCNNode(geometry: originSphere)
        originNode.position = SCNVector3(0, 0, 0)
        rootNode.addChildNode(originNode)
    }
    
    func addAxisLine(from start: SCNVector3, to end: SCNVector3, color: UIColor) {
        let vertices: [SCNVector3] = [start, end]
        let data = Data(bytes: vertices, count: vertices.count * MemoryLayout<SCNVector3>.size)
        
        let vertexSource = SCNGeometrySource(data: data,
                                            semantic: .vertex,
                                            vectorCount: vertices.count,
                                            usesFloatComponents: true,
                                            componentsPerVector: 3,
                                            bytesPerComponent: MemoryLayout<Float>.size,
                                            dataOffset: 0,
                                            dataStride: MemoryLayout<SCNVector3>.size)
        
        let indices: [Int32] = [0, 1]
        let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<Int32>.size)
        
        let element = SCNGeometryElement(data: indexData,
                                        primitiveType: .line,
                                        primitiveCount: 1,
                                        bytesPerIndex: MemoryLayout<Int32>.size)
        
        let line = SCNGeometry(sources: [vertexSource], elements: [element])
        line.firstMaterial?.diffuse.contents = color
        line.firstMaterial?.lightingModel = .constant
        
        let lineNode = SCNNode(geometry: line)
        rootNode.addChildNode(lineNode)
    }
    
    func addAxisLabel(text: String, position: SCNVector3, color: UIColor) {
        let textGeometry = SCNText(string: text, extrusionDepth: 0.1)
        textGeometry.font = UIFont.boldSystemFont(ofSize: 1.0)
        textGeometry.firstMaterial?.diffuse.contents = color
        textGeometry.firstMaterial?.lightingModel = .constant
        
        let textNode = SCNNode(geometry: textGeometry)
        textNode.position = position
        
        // Scale down the text to be more appropriate for the scene
        textNode.scale = SCNVector3(0.5, 0.5, 0.5)
        
        // Make text face the camera by applying rotation
        // Rotate to face the camera's general direction
        textNode.eulerAngles = SCNVector3(x: -Float.pi / 4, y: Float.pi / 4, z: 0)
        
        // Center the text on its position
        let (min, max) = textGeometry.boundingBox
        let dx = (max.x - min.x) / 2.0
        let dy = (max.y - min.y) / 2.0
        textNode.pivot = SCNMatrix4MakeTranslation(dx, dy, 0)
        
        rootNode.addChildNode(textNode)
    }
    
    func createBall() {
        // Create a sphere geometry with radius 0.5 (diameter = 1 block)
        let sphere = SCNSphere(radius: 0.5)
        
        // Create material for the ball (bright red color)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0)  // Bright red
        material.lightingModel = .lambert
        material.specular.contents = UIColor.white  // Add some shine
        sphere.materials = [material]
        
        // Create node for the ball
        ballNode = SCNNode(geometry: sphere)
        ballNode.name = "Ball"  // Name it for debugging
        
        // Position the ball at a starting location (near center, elevated)
        ballNode.position = SCNVector3(x: 30, y: 5, z: 30)  // Start at center of map, 5 blocks high
        
        // Enable physics for the ball
        let physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: sphere))
        physicsBody.mass = 1.0
        physicsBody.restitution = 0.3  // Some bounciness
        physicsBody.friction = 0.5     // Medium friction
        physicsBody.rollingFriction = 0.2  // Allow rolling
        physicsBody.damping = 0.1      // Small air resistance
        physicsBody.angularDamping = 0.1
        ballNode.physicsBody = physicsBody
        
        rootNode.addChildNode(ballNode)
        
        // Enable physics on the world
        physicsWorld.speed = 1.0
        physicsWorld.gravity = SCNVector3(0, -98.0, 0)  // Strong gravity (10x Earth gravity) - ball falls immediately
    }
    
    // Move the ball with controller input (x and z are -1 to 1 range)
    func moveBall(x: Float, z: Float) {
        // Store current input for physics update
        currentMoveX = x
        currentMoveZ = z
    }
    
    // Update ball physics based on current input (called every frame)
    func updateBallPhysics() {
        guard let physicsBody = ballNode.physicsBody else { return }
        
        // Apply movement based on stored controller input
        let speed: Float = 8.0  // Units per second
        let newVelocity = SCNVector3(
            x: currentMoveX * speed,
            y: physicsBody.velocity.y,  // Preserve vertical velocity (for jumping/falling)
            z: currentMoveZ * speed
        )
        physicsBody.velocity = newVelocity
    }
    
    // Move the ball with direct velocity (legacy method for other controls)
    func moveBall(direction: SCNVector3) {
        guard let physicsBody = ballNode.physicsBody else { return }
        
        // Set velocity directly instead of applying force
        // This gives immediate, precise control over the ball's movement
        let speed: Float = 8.0  // Units per second
        let newVelocity = SCNVector3(
            x: direction.x * speed,
            y: physicsBody.velocity.y,  // Preserve vertical velocity (for jumping/falling)
            z: direction.z * speed
        )
        physicsBody.velocity = newVelocity
    }
    
    // Jump the ball - just enough to clear 1 block height
    func jumpBall() {
        guard let physicsBody = ballNode.physicsBody else { return }
        
        // Apply upward impulse calculated to reach 1 block (1 unit) height
        // With gravity -98.0 and mass 1.0: v = sqrt(2 * 98.0 * 1.0) ≈ 14.0
        // Using impulse: force = mass * velocity = 1.0 * 14.0
        let jumpForce = SCNVector3(0, 14.0, 0)
        physicsBody.applyForce(jumpForce, asImpulse: true)
    }
    
    // Update camera to follow ball (call this every frame)
    func updateCamera() {
        updateCameraFrameCount += 1
        
        // IMPORTANT: Use presentation node to get the actual rendered position during physics simulation
        // ballNode.position gives the model position (start of simulation)
        // ballNode.presentation.position gives the actual current rendered position
        guard let ballPosition = ballNode?.presentation.position else { return }
        
        // Log ball position periodically
        if updateCameraFrameCount % 60 == 0 {  // Log every second at 60fps
            print("📹 Camera update frame \(updateCameraFrameCount)")
            print("   ⚽ Ball position: (\(String(format: "%.2f", ballPosition.x)), \(String(format: "%.2f", ballPosition.y)), \(String(format: "%.2f", ballPosition.z)))")
            if let velocity = ballNode.physicsBody?.velocity {
                print("   🏃 Ball velocity: (\(String(format: "%.2f", velocity.x)), \(String(format: "%.2f", velocity.y)), \(String(format: "%.2f", velocity.z)))")
            }
        }
        
        // Camera positioning based on down angle and distance
        // droneAngle: angle down from horizontal (10° = nearly horizontal, 90° = straight down)
        // droneDistance: how far from the ball
        
        // Convert angle to radians
        let angleRadians = droneAngle * Float.pi / 180.0
        
        // Calculate camera position using trigonometry to maintain CONSTANT distance
        // Height above ball = distance * sin(angle)
        // Horizontal offset behind ball = distance * cos(angle)
        let cameraHeight = droneDistance * sin(angleRadians)
        let horizontalOffset = droneDistance * cos(angleRadians)
        
        // Calculate target camera position using orbit angle (ALWAYS use orbit angle to avoid snapping)
        // When searching: increment angle to orbit around ball
        // When not searching: keep current angle (wherever ball was found)
        
        if isSearchingForBall {
            // ORBIT MODE: Increment frame counter and rotate to next position when ready
            framesInCurrentOrbitPosition += 1
            
            // Check if it's time to rotate to next position
            if framesInCurrentOrbitPosition >= framesBeforeNextOrbit {
                cameraOrbitAngle += orbitStepDegrees
                if cameraOrbitAngle >= 360.0 {
                    cameraOrbitAngle = 0.0
                }
                framesInCurrentOrbitPosition = 0
                print("🔄 Orbiting to next position: \(String(format: "%.0f", cameraOrbitAngle))°")
            }
        }
        // In normal mode, we keep the current cameraOrbitAngle (don't change it)
        // This means the camera stays at whatever angle it found the ball
        
        // Calculate target position using current orbit angle
        let orbitRadians = cameraOrbitAngle * Float.pi / 180.0
        let targetCameraX = ballPosition.x + horizontalOffset * sin(orbitRadians)
        let targetCameraZ = ballPosition.z + horizontalOffset * cos(orbitRadians)
        let targetCameraY = ballPosition.y + cameraHeight
        let targetPosition = SCNVector3(x: targetCameraX, y: targetCameraY, z: targetCameraZ)
        
        // Smooth camera movement to avoid jerkiness
        // Use slower smoothing during orbit search for smoother transitions
        let smoothingXZ: Float = isSearchingForBall ? 0.08 : 0.2  // Slower when searching
        let smoothingY: Float = 0.1  // Slow vertical tracking
        
        cameraNode.position.x += (targetPosition.x - cameraNode.position.x) * smoothingXZ
        cameraNode.position.y += (targetPosition.y - cameraNode.position.y) * smoothingY
        cameraNode.position.z += (targetPosition.z - cameraNode.position.z) * smoothingXZ
        
        // Calculate actual distance from camera to ball
        let dx = cameraNode.position.x - ballPosition.x
        let dy = cameraNode.position.y - ballPosition.y
        let dz = cameraNode.position.z - ballPosition.z
        let actualDistance = sqrt(dx*dx + dy*dy + dz*dz)
        
        // Report distance to HUD (every frame)
        distanceUpdateCount += 1
        if distanceUpdateCount % 60 == 0 {  // Log every second at 60fps
            print("📏 Distance update #\(distanceUpdateCount): \(String(format: "%.1f", actualDistance)) (target: \(droneDistance))")
        }
        onDistanceChanged?(actualDistance)
        
        // Check if ball is visible from CURRENT camera position
        let currentFrameVisible = isBallVisibleFromPosition(cameraNode.position, ballPosition: ballPosition)
        
        // Apply temporal smoothing - require multiple consecutive frames before changing state
        if currentFrameVisible {
            visibleFrameCount += 1
            hiddenFrameCount = 0
        } else {
            hiddenFrameCount += 1
            visibleFrameCount = 0
        }
        
        // Determine smoothed visibility state
        var isVisible = lastVisibilityState  // Start with previous state
        
        if lastVisibilityState && hiddenFrameCount >= visibilityChangeThreshold {
            // Was visible, now hidden for multiple frames -> change to hidden
            isVisible = false
        } else if !lastVisibilityState && visibleFrameCount >= visibilityChangeThreshold {
            // Was hidden, now visible for multiple frames -> change to visible
            isVisible = true
        }
        
        // Update HUD and log changes
        if isVisible != lastVisibilityState {
            lastVisibilityState = isVisible
            onBallVisibilityChanged?(isVisible)
            print("🎯 BALL VISIBILITY CHANGED: \(isVisible ? "VISIBLE ✅" : "NOT VISIBLE ❌") (after \(isVisible ? visibleFrameCount : hiddenFrameCount) frames)")
            
            // Handle search mode transitions
            if !isVisible && !isSearchingForBall {
                // Ball just became hidden -> start searching
                isSearchingForBall = true
                framesInCurrentOrbitPosition = 0
                // Initialize orbit angle to current camera angle relative to ball
                let currentDx = cameraNode.position.x - ballPosition.x
                let currentDz = cameraNode.position.z - ballPosition.z
                cameraOrbitAngle = atan2(currentDx, currentDz) * 180.0 / Float.pi
                if cameraOrbitAngle < 0 { cameraOrbitAngle += 360.0 }
                print("🔍 STARTING ORBIT SEARCH at \(String(format: "%.0f", cameraOrbitAngle))°")
            } else if isVisible && isSearchingForBall {
                // Ball just became visible -> stop searching (keep current angle)
                isSearchingForBall = false
                framesInCurrentOrbitPosition = 0
                print("✅ ORBIT SEARCH COMPLETE - Ball found at \(String(format: "%.0f", cameraOrbitAngle))°")
            }
        }
        
        // Look directly at the ball
        cameraNode.look(at: ballPosition)
        
        // Update directional light to follow the ball (keep it above the ball for consistent lighting)
        let lightX = ballPosition.x
        let lightY: Float = 80.0  // Fixed height above the scene
        let lightZ = ballPosition.z
        directionalLightNode.position = SCNVector3(x: lightX, y: lightY, z: lightZ)
        directionalLightNode.look(at: ballPosition)
    }
    
    // Check if ball is visible from given camera position (not occluded by buildings)
    // Uses screen-space hit testing to check if ball is actually visible in rendered view
    func isBallVisibleFromPosition(_ cameraPos: SCNVector3, ballPosition: SCNVector3) -> Bool {
        visibilityRaycastCount += 1
        let shouldLog = (visibilityRaycastCount <= 15 || visibilityRaycastCount % 120 == 0)
        
        if shouldLog {
            print("🔍 Visibility check #\(visibilityRaycastCount)")
            print("  📍 Camera: (\(String(format: "%.1f", cameraPos.x)), \(String(format: "%.1f", cameraPos.y)), \(String(format: "%.1f", cameraPos.z)))")
            print("  ⚽ Ball: (\(String(format: "%.1f", ballPosition.x)), \(String(format: "%.1f", ballPosition.y)), \(String(format: "%.1f", ballPosition.z)))")
        }
        
        // APPROACH: Use screen-space hit testing
        // Project ball position to screen coordinates, then hit test at those pixels
        // This accounts for actual rendering, not just geometric occlusion
        
        guard let view = sceneView else {
            if shouldLog { print("  ⚠️  No sceneView reference") }
            return true  // Assume visible if we can't test
        }
        
        // Project 3D ball position to 2D screen coordinates
        let ballScreenPos = view.projectPoint(ballPosition)
        let screenPoint = CGPoint(x: CGFloat(ballScreenPos.x), y: CGFloat(ballScreenPos.y))
        
        if shouldLog {
            print("  📱 Screen pos: (\(String(format: "%.1f", screenPoint.x)), \(String(format: "%.1f", screenPoint.y)))")
        }
        
        // Check if screen point is within view bounds
        guard view.bounds.contains(screenPoint) else {
            if shouldLog { print("  ❌ Ball off-screen (outside view bounds)") }
            return false
        }
        
        // Hit test at the ball's screen position
        let hitOptions: [SCNHitTestOption: Any] = [
            .searchMode: SCNHitTestSearchMode.closest.rawValue as NSNumber,
            .ignoreHiddenNodes: true as NSNumber
        ]
        
        let hits = view.hitTest(screenPoint, options: hitOptions)
        
        if hits.isEmpty {
            if shouldLog { print("  ⚠️  No hits at screen position") }
            return false
        }
        
        // Check if the first hit is the ball (or very close to ball distance)
        if let firstHit = hits.first {
            let hitNodeName = firstHit.node.name ?? "unnamed"
            let isBall = (firstHit.node == ballNode)
            
            // Also check distance - if hit is very close to ball distance, consider it visible
            // (handles cases where we hit ball's physics body or child nodes)
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
            let isNearBall = distanceDiff < 1.0  // Within 1 unit
            
            if shouldLog {
                print("  🎯 Hit: '\(hitNodeName)' at distance \(String(format: "%.1f", hitDistance))")
                print("  📏 Ball distance: \(String(format: "%.1f", ballDistance)), diff: \(String(format: "%.1f", distanceDiff))")
            }
            
            if isBall || isNearBall {
                if shouldLog { print("  ✅ BALL VISIBLE") }
                return true
            } else {
                if shouldLog { print("  ❌ Blocked by '\(hitNodeName)'") }
                return false
            }
        }
        
        return false
    }
    
    // Calculate horizontal offset needed to recenter ball
    func calculateOffsetToRecenterBall(cameraPos: SCNVector3, ballPos: SCNVector3, cameraHeight: Float) -> SCNVector3 {
        // Calculate the horizontal difference between camera and ball (ignoring Y)
        let deltaX = ballPos.x - cameraPos.x
        let deltaZ = ballPos.z - cameraPos.z
        
        // Return offset to move camera toward ball's horizontal position
        // This keeps height constant but adjusts X and Z
        return SCNVector3(deltaX * 0.1, 0, deltaZ * 0.1)  // Move 10% toward ball each frame
    }
    
    // Update ambient light intensity
    func updateAmbientLight(_ intensity: Float) {
        ambientLightIntensity = intensity
        ambientLightNode?.light?.color = UIColor(white: CGFloat(intensity), alpha: 1.0)
        print("GameScene3D: Ambient light updated to \(intensity)")
    }
    
    // Update shadows enabled/disabled
    func updateShadows(_ enabled: Bool) {
        shadowsEnabled = enabled
        directionalLightNode?.light?.castsShadow = enabled
        
        // Update all blocks
        blockNodes.forEach { node in
            node.castsShadow = enabled
        }
        
        // Update ball
        ballNode?.castsShadow = enabled
        
        print("GameScene3D: Shadows \(enabled ? "enabled" : "disabled")")
    }
}

// Helper extension for distance calculation
extension SCNVector3 {
    func distance(to other: SCNVector3) -> Float {
        let dx = self.x - other.x
        let dy = self.y - other.y
        let dz = self.z - other.z
        return sqrt(dx * dx + dy * dy + dz * dz)
    }
}
