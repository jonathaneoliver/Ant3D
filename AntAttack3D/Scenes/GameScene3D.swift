import SceneKit
import UIKit
import os.log

// Create logger for GameScene3D
private let logger = Logger(subsystem: "com.example.AntAttack3D", category: "GameScene")

class GameScene3D: SCNScene {
    
    // MARK: - Scene Components
    var cityMap: CityMap3D!
    var cameraNode: SCNNode!
    var blockNodes: [SCNNode] = []
    var ballNode: SCNNode!
    var directionalLightNode: SCNNode!
    var ambientLightNode: SCNNode!
    weak var sceneView: SCNView?
    
    // MARK: - Game Entities
    var enemyBalls: [EnemyBall] = []
    var hostages: [Hostage] = []
    var safeMatPosition: SCNVector3 = SCNVector3Zero
    var safeMatRadius: Float = 3.0
    
    // MARK: - Game Systems
    var cameraSystem: CameraSystem!
    var physicsSystem: PhysicsSystem!
    var aiSystem: AISystem!
    var gameStateSystem: GameStateSystem!
    var spawnSystem: SpawnSystem!
    
    // MARK: - Rendering Resources (Shared for performance)
    private var sharedBlockGeometry: SCNBox!
    private var sharedBlockMaterials: [SCNMaterial] = []
    private var sharedPhysicsShape: SCNPhysicsShape!
    
    // MARK: - Config-Server Parameters
    var ambientLightIntensity: Float = 0.5
    var shadowsEnabled: Bool = false
    
    override init() {
        super.init()
        logger.info("GameScene3D initialized")
        
        // Initialize systems BEFORE setupScene
        initializeSystems()
        
        setupScene()
        setupConfigListener()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initializeSystems()
        setupScene()
        setupConfigListener()
    }
    
    // MARK: - System Initialization
    
    /// Initialize all game systems
    private func initializeSystems() {
        cameraSystem = CameraSystem()
        cameraSystem.scene = self
        
        physicsSystem = PhysicsSystem()
        physicsSystem.scene = self
        
        aiSystem = AISystem()
        aiSystem.scene = self
        
        gameStateSystem = GameStateSystem()
        gameStateSystem.scene = self
        
        spawnSystem = SpawnSystem()
        spawnSystem.scene = self
    }
    
    // MARK: - Scene Setup
    
    func setupConfigListener() {
        ConfigManager.shared.onConfigUpdate = { [weak self] config in
            self?.onConfigReceived(config)
        }
    }
    
    func onConfigReceived(_ config: GameConfig) {
        logger.debug("Config update: angle=\(config.droneAngle)°, distance=\(config.droneDistance)")
        
        // Update camera system config
        cameraSystem.updateConfig(
            droneAngle: config.droneAngle,
            droneDistance: config.droneDistance,
            orbitSearchDelay: config.orbitSearchDelay
        )
        
        // Update fog distances if changed
        if abs(self.fogStartDistance - CGFloat(config.fogStartDistance)) > 0.01 ||
           abs(self.fogEndDistance - CGFloat(config.fogEndDistance)) > 0.01 {
            self.fogStartDistance = CGFloat(config.fogStartDistance)
            self.fogEndDistance = CGFloat(config.fogEndDistance)
        }
        
        self.updateAmbientLight(config.ambientLight)
        self.updateShadows(config.shadowsEnabled)
    }
    
    // MARK: - Map Loading
    
    func loadMap(mapData: MapData) {
        // Check if this is a heightMap format (Ant Attack style)
        if let heightMap = mapData.heightMap {
            cityMap = CityMap3D(heightMap: heightMap)
        } else {
            cityMap = CityMap3D(mapData: mapData)
        }
        
        // Re-render the city with new map
        blockNodes.forEach { $0.removeFromParentNode() }
        blockNodes.removeAll()
        
        renderCity()
        
        // Update camera to center on new map size
        cameraSystem.updateCameraForMapSize(cityMap: cityMap)
    }
    
    func setupScene() {
        NSLog("🏗️  GameScene setupScene started")
        
        // Set background color
        background.contents = UIColor(red: 0.59, green: 0.85, blue: 0.93, alpha: 1.0)
        
        // Create temporary city map (will be replaced with Ant Attack Original)
        cityMap = CityMap3D(width: GameConstants.Map.defaultWidth, height: GameConstants.Map.defaultHeight, useAntAttackMap: false)
        
        // Setup camera
        setupCamera()
        
        // Setup lighting
        setupLighting()
        
        // Render the city
        renderCity()
        
        // Add axis labels
        addAxisLabels()
        
        // Create the ball
        spawnSystem.createBall()
        
        // Create enemy balls
        spawnSystem.createEnemyBalls()
        
        // Create hostages to rescue
        spawnSystem.createHostages()
        
        // Setup all systems
        cameraSystem.setup()
        physicsSystem.setup()
        aiSystem.setup()
        gameStateSystem.setup()
        spawnSystem.setup()
        
        // Load Ant Attack Original map asynchronously
        loadAntAttackOriginalMap()
    }
    
    private func loadAntAttackOriginalMap() {
        // First, try to load the bundled map
        if let bundledMap = ConfigManager.shared.loadBundledAntAttackMap() {
            loadMap(mapData: bundledMap)
            
            // Optionally fetch updated version from server in background
            ConfigManager.shared.fetchMap(name: "Ant_Attack_Original") { [weak self] result in
                switch result {
                case .success(let serverMap):
                    self?.loadMap(mapData: serverMap)
                case .failure:
                    break  // Server unavailable, continue with bundled map
                }
            }
        } else {
            // Bundled map failed to load, try server
            ConfigManager.shared.fetchMap(name: "Ant_Attack_Original") { [weak self] result in
                switch result {
                case .success(let mapData):
                    self?.loadMap(mapData: mapData)
                    
                case .failure(let error):
                    logger.error("Failed to load map: \(error.localizedDescription)")
                    // Final fallback: replace with procedural map
                    DispatchQueue.main.async {
                        self?.cityMap = CityMap3D(width: 60, height: 60, useAntAttackMap: true)
                        self?.blockNodes.forEach { $0.removeFromParentNode() }
                        self?.blockNodes.removeAll()
                        self?.renderCity()
                        self?.cameraSystem.updateCameraForMapSize(cityMap: self!.cityMap)
                    }
                }
            }
        }
    }
    
    func setupCamera() {
        // Create camera node
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        
        // Use perspective projection
        cameraNode.camera?.usesOrthographicProjection = false
        cameraNode.camera?.fieldOfView = 60.0
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 80.0
        
        // Add fog
        fogStartDistance = 40.0
        fogEndDistance = 80.0
        fogColor = UIColor(red: 0.59, green: 0.85, blue: 0.93, alpha: 1.0)
        fogDensityExponent = 2.0
        
        // Position camera
        let centerX = Float(cityMap.width) / 2.0
        let centerZ = Float(cityMap.height) / 2.0
        cameraNode.position = SCNVector3(x: centerX, y: 15, z: centerZ + 30)
        cameraNode.look(at: SCNVector3(x: centerX, y: 10, z: centerZ))
        
        rootNode.addChildNode(cameraNode)
    }
    
    func setupLighting() {
        // Ambient light
        ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light?.type = .ambient
        ambientLightNode.light?.color = UIColor(white: CGFloat(ambientLightIntensity), alpha: 1.0)
        rootNode.addChildNode(ambientLightNode)
        
        // Directional light
        directionalLightNode = SCNNode()
        directionalLightNode.light = SCNLight()
        directionalLightNode.light?.type = .directional
        directionalLightNode.light?.color = UIColor(white: 0.7, alpha: 1.0)
        directionalLightNode.light?.castsShadow = false
        
        let centerX = Float(cityMap.width) / 2.0
        let centerZ = Float(cityMap.height) / 2.0
        directionalLightNode.position = SCNVector3(x: centerX, y: 80, z: centerZ)
        directionalLightNode.look(at: SCNVector3(x: centerX, y: 0, z: centerZ))
        
        rootNode.addChildNode(directionalLightNode)
    }
    
    // MARK: - City Rendering
    
    func renderCity() {
        // Clear existing blocks
        blockNodes.forEach { $0.removeFromParentNode() }
        blockNodes.removeAll()
        
        // Initialize shared geometry and materials
        initializeSharedBlockResources()
        
        // Create flat ground
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
        
        // Create ramps
        for ramp in cityMap.ramps {
            createRamp(ramp: ramp)
        }
    }
    
    func initializeSharedBlockResources() {
        sharedBlockGeometry = SCNBox(width: 1.0, height: 1.0, length: 1.0, chamferRadius: 0.0)
        sharedBlockMaterials = createSharedBlockMaterials()
        sharedBlockGeometry.materials = sharedBlockMaterials
        
        sharedPhysicsShape = SCNPhysicsShape(
            geometry: SCNBox(width: 1.0, height: 1.0, length: 1.0, chamferRadius: 0.0),
            options: nil
        )
    }
    
    func createSharedBlockMaterials() -> [SCNMaterial] {
        var materials: [SCNMaterial] = []
        
        let topMaterial = SCNMaterial()
        topMaterial.diffuse.contents = UIColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1.0)
        topMaterial.lightingModel = GameConstants.Materials.lightingModel
        
        let sideMaterial1 = SCNMaterial()
        sideMaterial1.diffuse.contents = UIColor(red: 0.65, green: 0.65, blue: 0.65, alpha: 1.0)
        sideMaterial1.lightingModel = GameConstants.Materials.lightingModel
        
        let sideMaterial2 = SCNMaterial()
        sideMaterial2.diffuse.contents = UIColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1.0)
        sideMaterial2.lightingModel = GameConstants.Materials.lightingModel
        
        let bottomMaterial = SCNMaterial()
        bottomMaterial.diffuse.contents = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        bottomMaterial.lightingModel = GameConstants.Materials.lightingModel
        
        materials.append(sideMaterial1)
        materials.append(sideMaterial2)
        materials.append(sideMaterial1)
        materials.append(sideMaterial2)
        materials.append(topMaterial)
        materials.append(bottomMaterial)
        
        return materials
    }
    
    func createGround() {
        let infiniteSize: CGFloat = CGFloat(max(cityMap.width, cityMap.height)) * 10.0
        let groundBox = SCNBox(width: infiniteSize, height: 0.1, length: infiniteSize, chamferRadius: 0.0)
        
        let groundMaterial = SCNMaterial()
        groundMaterial.diffuse.contents = UIColor(red: 0.87, green: 0.72, blue: 0.53, alpha: 1.0)
        groundMaterial.lightingModel = GameConstants.Materials.lightingModel
        groundMaterial.isDoubleSided = false
        
        groundBox.materials = Array(repeating: groundMaterial, count: 6)
        
        let groundNode = SCNNode(geometry: groundBox)
        groundNode.position = SCNVector3(
            x: Float(cityMap.width) / 2.0 - 0.5,
            y: -0.55,
            z: Float(cityMap.height) / 2.0 - 0.5
        )
        
        rootNode.addChildNode(groundNode)
        blockNodes.append(groundNode)
        
        groundNode.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: groundBox))
        groundNode.physicsBody?.restitution = 0.1
        groundNode.physicsBody?.friction = 0.8
    }
    
    func createBlock(x: Int, y: Int, z: Int) {
        let blockNode = SCNNode(geometry: sharedBlockGeometry)
        blockNode.castsShadow = false
        
        blockNode.position = SCNVector3(
            x: Float(x),
            y: Float(z) + 0.5,
            z: Float(y)
        )
        
        blockNode.physicsBody = SCNPhysicsBody(type: .static, shape: sharedPhysicsShape)
        blockNode.physicsBody?.restitution = 0.1
        blockNode.physicsBody?.friction = 0.8
        
        rootNode.addChildNode(blockNode)
        blockNodes.append(blockNode)
    }
    
    func createRamp(ramp: Ramp) {
        let depth: Float = ramp.isShallow ? 2.0 : 1.0
        let halfDepth = depth / 2.0
        
        // Define vertices for wedge shape
        let vertices: [SCNVector3] = [
            SCNVector3(-0.5, -0.5, -halfDepth),
            SCNVector3(0.5, -0.5, -halfDepth),
            SCNVector3(0.5, -0.5, halfDepth),
            SCNVector3(-0.5, -0.5, halfDepth),
            SCNVector3(-0.5, 0.5, halfDepth),
            SCNVector3(0.5, 0.5, halfDepth),
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
        
        let uvCoordinates: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0),
            CGPoint(x: 1, y: 1),
            CGPoint(x: 0, y: 1),
            CGPoint(x: 0, y: 1),
            CGPoint(x: 1, y: 1),
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
        
        let indices: [Int32] = [
            0, 2, 1, 0, 3, 2,  // Bottom
            0, 1, 5, 0, 5, 4,  // Sloped face
            0, 4, 3,            // Left face
            1, 2, 5,            // Right face
            3, 4, 5, 3, 5, 2,  // Back face
        ]
        
        let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<Int32>.size)
        let element = SCNGeometryElement(data: indexData,
                                        primitiveType: .triangles,
                                        primitiveCount: indices.count / 3,
                                        bytesPerIndex: MemoryLayout<Int32>.size)
        
        let rampGeometry = SCNGeometry(sources: [vertexSource, uvSource], elements: [element])
        
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1.0)
        material.lightingModel = GameConstants.Materials.lightingModel
        material.isDoubleSided = true
        material.normal.contents = createStairsNormalMap()
        material.normal.intensity = 2.0
        
        rampGeometry.materials = [material]
        
        let rampNode = SCNNode(geometry: rampGeometry)
        rampNode.castsShadow = false
        
        // Calculate position and rotation based on ramp direction
        var xOffset: Float = 0
        var zOffset: Float = 0
        
        if ramp.isShallow {
            switch ramp.direction {
            case 0: zOffset = 0.5
            case 1: xOffset = 0.5
            case 2: zOffset = -0.5
            case 3: xOffset = -0.5
            default: break
            }
        }
        
        rampNode.position = SCNVector3(
            x: Float(ramp.x) + xOffset,
            y: Float(ramp.z) + 0.5,
            z: Float(ramp.y) + zOffset
        )
        
        switch ramp.direction {
        case 0: rampNode.eulerAngles.y = Float.pi
        case 1: rampNode.eulerAngles.y = Float.pi / 2
        case 2: rampNode.eulerAngles.y = 0
        case 3: rampNode.eulerAngles.y = -Float.pi / 2
        default: break
        }
        
        let rampBox = SCNBox(width: 1.0, height: 1.0, length: CGFloat(depth), chamferRadius: 0.0)
        let rampShape = SCNPhysicsShape(geometry: rampBox, options: nil)
        rampNode.physicsBody = SCNPhysicsBody(type: .static, shape: rampShape)
        rampNode.physicsBody?.restitution = 0.1
        rampNode.physicsBody?.friction = 1.5
        
        rootNode.addChildNode(rampNode)
        blockNodes.append(rampNode)
    }
    
    func createStairsNormalMap() -> UIImage {
        let size = 512
        let stepsCount = 10
        let stepHeight = size / stepsCount
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: size, height: size), true, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return UIImage()
        }
        
        context.setFillColor(UIColor(red: 0.5, green: 0.5, blue: 1.0, alpha: 1.0).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        
        for step in 0..<stepsCount {
            let y = CGFloat(step * stepHeight)
            let edgeHeight: CGFloat = 6
            
            context.setFillColor(UIColor(red: 0.5, green: 0.65, blue: 0.9, alpha: 1.0).cgColor)
            context.fill(CGRect(x: 0, y: y, width: CGFloat(size), height: CGFloat(stepHeight - Int(edgeHeight))))
            
            context.setFillColor(UIColor(red: 0.5, green: 0.35, blue: 0.7, alpha: 1.0).cgColor)
            context.fill(CGRect(x: 0, y: y + CGFloat(stepHeight) - edgeHeight, width: CGFloat(size), height: edgeHeight))
        }
        
        let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        
        return image
    }
    
    func addAxisLabels() {
        // X-axis (red)
        addAxisLine(from: SCNVector3(0, 0, 0), to: SCNVector3(3, 0, 0), color: .red)
        addAxisLabel(text: "X", position: SCNVector3(3.5, 0, 0), color: .red)
        
        // Y-axis (green)
        addAxisLine(from: SCNVector3(0, 0, 0), to: SCNVector3(0, 3, 0), color: .green)
        addAxisLabel(text: "Y", position: SCNVector3(0, 3.5, 0), color: .green)
        
        // Z-axis (blue)
        addAxisLine(from: SCNVector3(0, 0, 0), to: SCNVector3(0, 0, 3), color: .blue)
        addAxisLabel(text: "Z", position: SCNVector3(0, 0, 3.5), color: .blue)
        
        // Origin sphere
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
        textNode.scale = SCNVector3(0.5, 0.5, 0.5)
        textNode.eulerAngles = SCNVector3(x: -Float.pi / 4, y: Float.pi / 4, z: 0)
        
        let (min, max) = textGeometry.boundingBox
        let dx = (max.x - min.x) / 2.0
        let dy = (max.y - min.y) / 2.0
        textNode.pivot = SCNMatrix4MakeTranslation(dx, dy, 0)
        
        rootNode.addChildNode(textNode)
    }
    
    // MARK: - Game Update Loop (called every frame)
    
    func update(deltaTime: TimeInterval) {
        physicsSystem.update(deltaTime: deltaTime)
        aiSystem.update(deltaTime: deltaTime)
        cameraSystem.update(deltaTime: deltaTime)
        gameStateSystem.update(deltaTime: deltaTime)
        spawnSystem.update(deltaTime: deltaTime)
    }
    
    // MARK: - Player Control (Delegation to PhysicsSystem)
    
    func moveBall(x: Float, z: Float) {
        physicsSystem.moveBall(x: x, z: z)
    }
    
    func moveBall(direction: SCNVector3) {
        // Convert direction vector to x/z components
        physicsSystem.moveBall(x: Float(direction.x), z: Float(direction.z))
    }
    
    func jumpBall() {
        physicsSystem.jumpBall()
    }
    
    func releaseJump() {
        physicsSystem.releaseJump()
    }
    
    // MARK: - Camera Control (Delegation to CameraSystem)
    
    func rotateCameraView() {
        cameraSystem.rotateCameraView()
    }
    
    // MARK: - Lighting Control
    
    func updateAmbientLight(_ intensity: Float) {
        ambientLightIntensity = intensity
        ambientLightNode?.light?.color = UIColor(white: CGFloat(intensity), alpha: 1.0)
        logger.debug("Ambient light: \(intensity)")
    }
    
    func updateShadows(_ enabled: Bool) {
        shadowsEnabled = enabled
        directionalLightNode?.light?.castsShadow = enabled
        
        blockNodes.forEach { node in
            node.castsShadow = enabled
        }
        
        ballNode?.castsShadow = enabled
        
        logger.debug("Shadows: \(enabled ? "enabled" : "disabled")")
    }
    
    // MARK: - Legacy Compatibility Methods
    
    // These properties/methods are accessed by GameViewController and need to delegate to systems
    
    var cameraOrbitAngle: Float {
        get { cameraSystem.cameraOrbitAngle }
        set { cameraSystem.cameraOrbitAngle = newValue }
    }
    
    var score: Int {
        get { gameStateSystem.score }
        set { gameStateSystem.score = newValue }
    }
    
    var currentLevel: Int {
        get { gameStateSystem.currentLevel }
        set { gameStateSystem.currentLevel = newValue }
    }
    
    var onBallVisibilityChanged: ((Bool) -> Void)? {
        get { cameraSystem.onBallVisibilityChanged }
        set { cameraSystem.onBallVisibilityChanged = newValue }
    }
    
    var onDistanceChanged: ((Float) -> Void)? {
        get { cameraSystem.onDistanceChanged }
        set { cameraSystem.onDistanceChanged = newValue }
    }
    
    var onScoreChanged: ((Int) -> Void)? {
        get { gameStateSystem.onScoreChanged }
        set { gameStateSystem.onScoreChanged = newValue }
    }
    
    var onLevelComplete: ((Int) -> Void)? {
        get { gameStateSystem.onLevelComplete }
        set { gameStateSystem.onLevelComplete = newValue }
    }
    
    var onHostageCountChanged: ((Int, Int) -> Void)? {
        get { gameStateSystem.onHostageCountChanged }
        set { gameStateSystem.onHostageCountChanged = newValue }
    }
    
    var onGameOver: (() -> Void)? {
        get { gameStateSystem.onGameOver }
        set { gameStateSystem.onGameOver = newValue }
    }
    
    func resetGameOver() {
        gameStateSystem.resetGameOver()
    }
    
    func restartLevel() {
        gameStateSystem.restartLevel()
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
