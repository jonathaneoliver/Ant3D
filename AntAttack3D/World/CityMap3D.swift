import Foundation

// Ramp structure to store ramp position and direction
struct Ramp {
    let x: Int
    let y: Int
    let z: Int
    let direction: Int  // 0=south (+y), 1=west (-x), 2=north (-y), 3=east (+x)
    let width: Int      // 1 or 2 blocks wide
    let height: Int     // Number of levels the ramp spans
    let isShallow: Bool // true = half-steep (2 forward for 1 up), false = normal (1 forward for 1 up)
}

// 3D City map generation and management
class CityMap3D {
    
    let width: Int
    let height: Int
    let maxLevels: Int = GameConstants.Map.maxLevels
    
    // 3D grid: [x][y][z] = true if block exists
    var blocks: [[[Bool]]]
    
    // List of ramps (diagonal blocks)
    var ramps: [Ramp] = []
    
    init(width: Int = GameConstants.Map.defaultWidth, height: Int = GameConstants.Map.defaultHeight, useAntAttackMap: Bool = true) {  // Larger map with more room for structures
        self.width = width
        self.height = height
        
        // Initialize empty 3D grid
        blocks = Array(repeating: Array(repeating: Array(repeating: false, count: maxLevels), count: height), count: width)
        
        if useAntAttackMap {
            generateAntAttackCity()
        } else {
            generateCity()
        }
    }
    
    // Initialize from loaded map data
    init(mapData: MapData) {
        self.width = mapData.width
        self.height = mapData.height
        
        // Load blocks from map data
        self.blocks = mapData.blocks
        
        // Convert RampData to Ramp objects
        self.ramps = mapData.ramps.map { rampData in
            Ramp(x: rampData.x, y: rampData.y, z: rampData.z,
                 direction: rampData.direction, width: rampData.width,
                 height: rampData.height, isShallow: rampData.isShallow)
        }
        
        print("✅ CityMap3D loaded from custom map data: \(mapData.name)")
        print("   Size: \(width)x\(height)x\(maxLevels)")
        print("   Blocks: \(countBlocks()), Ramps: \(ramps.count)")
    }
    
    // Initialize from height map with bitmap encoding (Ant Attack format)
    // Each value 0-63 is a 9-bit bitmap where bit N indicates a block at Z-level N
    init(heightMap: [[Int]]) {
        self.height = heightMap.count        // Number of rows
        self.width = heightMap[0].count      // Number of columns
        
        // Initialize 3D grid with 9 Z-levels (0-8)
        let zLevels = 9
        blocks = Array(repeating: Array(repeating: Array(repeating: false, count: zLevels), count: height), count: width)
        
        // Decode bitmap values into 3D blocks
        for row in 0..<height {
            for col in 0..<width {
                let bitmask = heightMap[row][col]
                
                // Check each bit (z-level 0-8)
                for z in 0..<zLevels {
                    let bit = (bitmask >> z) & 1
                    if bit == 1 {
                        blocks[col][row][z] = true
                    }
                }
            }
        }
        
        print("✅ CityMap3D loaded from height map bitmap")
        print("   Size: \(width)x\(height)x\(zLevels)")
        print("   Blocks: \(countBlocks())")
    }
    
    // Helper to count total blocks
    private func countBlocks() -> Int {
        var count = 0
        for x in 0..<width {
            for y in 0..<height {
                for z in 0..<maxLevels {
                    if blocks[x][y][z] { count += 1 }
                }
            }
        }
        return count
    }
    
    // Make a 4x4x4 box with a 4x2x2 hole through the middle (proper arch)
    // The hole goes through in the Y direction (forward/back)
    func makeArch(x: Int, y: Int) {
        // Fill the entire 4x4x4 volume first
        for px in 0..<4 {
            for py in 0..<4 {
                for pz in 0..<4 {
                    let blockX = x + px
                    let blockY = y + py
                    if blockX >= 0 && blockX < width && blockY >= 0 && blockY < height && pz < maxLevels {
                        blocks[blockX][blockY][pz] = true
                    }
                }
            }
        }
        
        // Now carve out the 4x2x2 hole through the middle
        // Hole spans: all 4 X positions, middle 2 Y positions (1,2), bottom 2 Z levels (0,1)
        for px in 0..<4 {
            for py in 1..<3 {  // Middle 2 positions in Y direction
                for pz in 0..<2 {  // Bottom 2 levels
                    let blockX = x + px
                    let blockY = y + py
                    if blockX >= 0 && blockX < width && blockY >= 0 && blockY < height {
                        blocks[blockX][blockY][pz] = false
                    }
                }
            }
        }
    }
    
    // Make a step pyramid (larger and taller) with ramps on one face
    func makeStepPyramid(x: Int, y: Int, size: Int, rampDirection: Int = 0, rampWidth: Int = 1, embeddedRamp: Bool = false) {
        let levels = min(size, maxLevels)
        
        // First, determine actual height by counting how many levels we'll actually build
        var actualHeight = 0
        for level in 0..<levels {
            let currentSize = size - (level * 2)
            if currentSize <= 0 { break }
            actualHeight = level + 1
        }
        
        // Build the pyramid blocks
        for level in 0..<actualHeight {
            let currentSize = size - (level * 2)
            
            let offset = level
            for px in 0..<currentSize {
                for py in 0..<currentSize {
                    let blockX = x + offset + px
                    let blockY = y + offset + py
                    if blockX >= 0 && blockX < width && blockY >= 0 && blockY < height {
                        blocks[blockX][blockY][level] = true
                    }
                }
            }
        }
        
        // Add ramps either embedded in the wall or external
        // Create ramps for all levels including the top
        for level in 0..<actualHeight {
            let offset = level  // Pyramid shrinks by 1 on each side per level
            let currentSize = size - (level * 2)
            
            // Place ramps based on direction - adjacent to or embedded in pyramid edge at this level
            // direction: 0=south (+y), 1=west (-x), 2=north (-y), 3=east (+x)
            switch rampDirection {
            case 0:  // South face
                let rampY = embeddedRamp ? (y + offset + currentSize - 1) : (y + offset + currentSize)
                let centerX = x + offset + (currentSize / 2)
                for i in 0..<rampWidth {
                    let rampX = centerX - (rampWidth / 2) + i
                    if rampX >= 0 && rampX < width && rampY >= 0 && rampY < height {
                        // If embedded, remove the block at this position
                        if embeddedRamp {
                            blocks[rampX][rampY][level] = false
                        }
                        ramps.append(Ramp(x: rampX, y: rampY, z: level, direction: 0, width: rampWidth, height: actualHeight, isShallow: false))
                    }
                }
            case 1:  // West face
                let rampX = embeddedRamp ? (x + offset) : (x + offset - 1)
                let centerY = y + offset + (currentSize / 2)
                for i in 0..<rampWidth {
                    let rampY = centerY - (rampWidth / 2) + i
                    if rampX >= 0 && rampX < width && rampY >= 0 && rampY < height {
                        // If embedded, remove the block at this position
                        if embeddedRamp {
                            blocks[rampX][rampY][level] = false
                        }
                        ramps.append(Ramp(x: rampX, y: rampY, z: level, direction: 1, width: rampWidth, height: actualHeight, isShallow: false))
                    }
                }
            case 2:  // North face
                let rampY = embeddedRamp ? (y + offset) : (y + offset - 1)
                let centerX = x + offset + (currentSize / 2)
                for i in 0..<rampWidth {
                    let rampX = centerX - (rampWidth / 2) + i
                    if rampX >= 0 && rampX < width && rampY >= 0 && rampY < height {
                        // If embedded, remove the block at this position
                        if embeddedRamp {
                            blocks[rampX][rampY][level] = false
                        }
                        ramps.append(Ramp(x: rampX, y: rampY, z: level, direction: 2, width: rampWidth, height: actualHeight, isShallow: false))
                    }
                }
            case 3:  // East face
                let rampX = embeddedRamp ? (x + offset + currentSize - 1) : (x + offset + currentSize)
                let centerY = y + offset + (currentSize / 2)
                for i in 0..<rampWidth {
                    let rampY = centerY - (rampWidth / 2) + i
                    if rampX >= 0 && rampX < width && rampY >= 0 && rampY < height {
                        // If embedded, remove the block at this position
                        if embeddedRamp {
                            blocks[rampX][rampY][level] = false
                        }
                        ramps.append(Ramp(x: rampX, y: rampY, z: level, direction: 3, width: rampWidth, height: actualHeight, isShallow: false))
                    }
                }
            default:
                break
            }
        }
    }
    
    // Make a wide step pyramid (shrinks by 2 on each side per level, less steep with wider plateaus)
    func makeWideStepPyramid(x: Int, y: Int, size: Int, rampDirection: Int = 0, rampWidth: Int = 1, embeddedRamp: Bool = false) {
        let levels = min(size / 2, maxLevels)  // Divide by 2 since we shrink by 4 total per level
        
        // First, determine actual height by counting how many levels we'll actually build
        var actualHeight = 0
        for level in 0..<levels {
            let currentSize = size - (level * 4)  // Shrink by 2 on each side = 4 total
            if currentSize <= 0 { break }
            actualHeight = level + 1
        }
        
        // Build the pyramid blocks
        for level in 0..<actualHeight {
            let currentSize = size - (level * 4)  // Shrink by 2 on each side per level
            
            let offset = level * 2  // Each level moves in by 2 blocks on each side
            for px in 0..<currentSize {
                for py in 0..<currentSize {
                    let blockX = x + offset + px
                    let blockY = y + offset + py
                    if blockX >= 0 && blockX < width && blockY >= 0 && blockY < height {
                        blocks[blockX][blockY][level] = true
                    }
                }
            }
        }
        
        // Add ramps either embedded in the wall or external
        // Create shallow ramps (2 blocks forward for 1 up) for all levels including the top
        for level in 0..<actualHeight {
            let offset = level * 2  // Pyramid shrinks by 2 on each side per level
            let currentSize = size - (level * 4)
            
            // Place ramps based on direction - adjacent to or embedded in pyramid edge at this level
            // direction: 0=south (+y), 1=west (-x), 2=north (-y), 3=east (+x)
            switch rampDirection {
            case 0:  // South face
                let rampY = embeddedRamp ? (y + offset + currentSize - 1) : (y + offset + currentSize)
                let centerX = x + offset + (currentSize / 2)
                for i in 0..<rampWidth {
                    let rampX = centerX - (rampWidth / 2) + i
                    if rampX >= 0 && rampX < width && rampY >= 0 && rampY < height {
                        // If embedded, remove the block at this position
                        if embeddedRamp {
                            blocks[rampX][rampY][level] = false
                        }
                        ramps.append(Ramp(x: rampX, y: rampY, z: level, direction: 0, width: rampWidth, height: actualHeight, isShallow: true))
                    }
                }
            case 1:  // West face
                let rampX = embeddedRamp ? (x + offset) : (x + offset - 1)
                let centerY = y + offset + (currentSize / 2)
                for i in 0..<rampWidth {
                    let rampY = centerY - (rampWidth / 2) + i
                    if rampX >= 0 && rampX < width && rampY >= 0 && rampY < height {
                        // If embedded, remove the block at this position
                        if embeddedRamp {
                            blocks[rampX][rampY][level] = false
                        }
                        ramps.append(Ramp(x: rampX, y: rampY, z: level, direction: 1, width: rampWidth, height: actualHeight, isShallow: true))
                    }
                }
            case 2:  // North face
                let rampY = embeddedRamp ? (y + offset) : (y + offset - 1)
                let centerX = x + offset + (currentSize / 2)
                for i in 0..<rampWidth {
                    let rampX = centerX - (rampWidth / 2) + i
                    if rampX >= 0 && rampX < width && rampY >= 0 && rampY < height {
                        // If embedded, remove the block at this position
                        if embeddedRamp {
                            blocks[rampX][rampY][level] = false
                        }
                        ramps.append(Ramp(x: rampX, y: rampY, z: level, direction: 2, width: rampWidth, height: actualHeight, isShallow: true))
                    }
                }
            case 3:  // East face
                let rampX = embeddedRamp ? (x + offset + currentSize - 1) : (x + offset + currentSize)
                let centerY = y + offset + (currentSize / 2)
                for i in 0..<rampWidth {
                    let rampY = centerY - (rampWidth / 2) + i
                    if rampX >= 0 && rampX < width && rampY >= 0 && rampY < height {
                        // If embedded, remove the block at this position
                        if embeddedRamp {
                            blocks[rampX][rampY][level] = false
                        }
                        ramps.append(Ramp(x: rampX, y: rampY, z: level, direction: 3, width: rampWidth, height: actualHeight, isShallow: true))
                    }
                }
            default:
                break
            }
        }
    }
    
    // Make a tower (tall column)
    func makeTower(x: Int, y: Int, height: Int, baseSize: Int = 2) {
        let towerHeight = min(height, maxLevels)
        
        for z in 0..<towerHeight {
            for px in 0..<baseSize {
                for py in 0..<baseSize {
                    let blockX = x + px
                    let blockY = y + py
                    if blockX >= 0 && blockX < width && blockY >= 0 && blockY < height {
                        blocks[blockX][blockY][z] = true
                    }
                }
            }
        }
    }
    
    // Make a platform (flat elevated area)
    func makePlatform(x: Int, y: Int, width: Int, depth: Int, height: Int) {
        let platformHeight = min(height, maxLevels)
        
        for z in 0..<platformHeight {
            for px in 0..<width {
                for py in 0..<depth {
                    let blockX = x + px
                    let blockY = y + py
                    if blockX >= 0 && blockX < self.width && blockY >= 0 && blockY < self.height {
                        blocks[blockX][blockY][z] = true
                    }
                }
            }
        }
    }
    
    // Make stairs (ascending blocks)
    func makeStairs(x: Int, y: Int, length: Int, direction: Int) {
        // direction: 0=+x, 1=+y, 2=-x, 3=-y
        for i in 0..<length {
            let height = min(i + 1, maxLevels)
            for z in 0..<height {
                var blockX = x
                var blockY = y
                
                switch direction {
                case 0: blockX = x + i
                case 1: blockY = y + i
                case 2: blockX = x - i
                case 3: blockY = y - i
                default: break
                }
                
                if blockX >= 0 && blockX < self.width && blockY >= 0 && blockY < self.height {
                    blocks[blockX][blockY][z] = true
                }
            }
        }
    }
    
    // Make a three layer pyramid (original smaller version)
    func makePyramid(x: Int, y: Int) {
        // Base layer - 5x3
        for px in 0..<5 {
            for py in 1..<4 {
                if x + px >= 0 && x + px < width && y + py >= 0 && y + py < height {
                    blocks[x + px][y + py][0] = true
                }
            }
        }
        
        // Middle layer - 3x3
        for px in 1..<4 {
            for py in 1..<4 {
                if x + px >= 0 && x + px < width && y + py >= 0 && y + py < height {
                    blocks[x + px][y + py][1] = true
                }
            }
        }
        
        // Top layer - 1x1
        if x + 2 >= 0 && x + 2 < width && y + 2 >= 0 && y + 2 < height {
            blocks[x + 2][y + 2][2] = true
        }
    }
    
    
    // Generate the classic Ant Attack city layout
    private func generateAntAttackCity() {
        // Build perimeter walls (1 block high)
        for x in 0..<width {
            for y in 0..<height {
                if x == 0 || x == width - 1 || y == 0 || y == height - 1 {
                    blocks[x][y][0] = true  // Only z=0 for 1 block high wall
                }
            }
        }
        
        // Classic Ant Attack style: Central pyramid complex with surrounding structures
        // The original game had a 256x256 grid - we'll scale to our 60x60 map
        
        // Central pyramid (large step pyramid at the center)
        let centerX = width / 2 - 6
        let centerY = height / 2 - 6
        makeStepPyramid(x: centerX, y: centerY, size: 12, rampDirection: 0, rampWidth: 2, embeddedRamp: true)
        
        // Four corner towers (inspired by the original game's corner structures)
        makeTower(x: 8, y: 8, height: 5, baseSize: 3)
        makeTower(x: width - 11, y: 8, height: 5, baseSize: 3)
        makeTower(x: 8, y: height - 11, height: 5, baseSize: 3)
        makeTower(x: width - 11, y: height - 11, height: 5, baseSize: 3)
        
        // Platforms connecting to corners (walkways)
        makePlatform(x: 12, y: 8, width: 8, depth: 3, height: 2)
        makePlatform(x: width - 20, y: 8, width: 8, depth: 3, height: 2)
        makePlatform(x: 8, y: 12, width: 3, depth: 8, height: 2)
        makePlatform(x: 8, y: height - 20, width: 3, depth: 8, height: 2)
        
        // Step pyramids around the perimeter (classic Ant Attack styling)
        makeStepPyramid(x: 15, y: 10, size: 8, rampDirection: 0, rampWidth: 2, embeddedRamp: false)
        makeStepPyramid(x: width - 23, y: 10, size: 8, rampDirection: 0, rampWidth: 2, embeddedRamp: false)
        makeStepPyramid(x: 15, y: height - 18, size: 8, rampDirection: 2, rampWidth: 2, embeddedRamp: false)
        makeStepPyramid(x: width - 23, y: height - 18, size: 8, rampDirection: 2, rampWidth: 2, embeddedRamp: false)
        
        // Mid-sized structures for gameplay variety
        makeWideStepPyramid(x: centerX - 10, y: centerY, size: 8, rampDirection: 3, rampWidth: 1, embeddedRamp: true)
        makeWideStepPyramid(x: centerX + 12, y: centerY, size: 8, rampDirection: 1, rampWidth: 1, embeddedRamp: true)
        
        // Scattered platforms at various heights (for vertical gameplay)
        makePlatform(x: 22, y: 22, width: 6, depth: 6, height: 3)
        makePlatform(x: width - 28, y: 22, width: 6, depth: 6, height: 3)
        makePlatform(x: 22, y: height - 28, width: 6, depth: 6, height: 3)
        makePlatform(x: width - 28, y: height - 28, width: 6, depth: 6, height: 3)
        
        // Arches throughout the city (classic Ant Attack feature)
        let archPositions: [(Int, Int)] = [
            (12, 20), (20, 12), (width - 16, 20), (20, height - 16),
            (width - 16, height - 16), (centerX - 8, centerY - 8),
            (centerX + 10, centerY - 8), (centerX - 8, centerY + 10),
            (centerX + 10, centerY + 10), (25, 35), (35, 25),
            (width - 29, 35), (35, height - 29)
        ]
        
        for pos in archPositions {
            if pos.0 >= 0 && pos.0 < width - 4 && pos.1 >= 0 && pos.1 < height - 4 {
                makeArch(x: pos.0, y: pos.1)
            }
        }
        
        // Smaller towers for additional vertical interest
        makeTower(x: 18, y: centerY, height: 4, baseSize: 2)
        makeTower(x: width - 20, y: centerY, height: 4, baseSize: 2)
        makeTower(x: centerX, y: 18, height: 4, baseSize: 2)
        makeTower(x: centerX, y: height - 20, height: 4, baseSize: 2)
        
        print("🏛️ Ant Attack city generated: \(width)x\(height) with central pyramid complex")
    }
    
    private func generateCity() {
        // Build 1-block high walls around the perimeter
        for x in 0..<width {
            for y in 0..<height {
                if x == 0 || x == width - 1 || y == 0 || y == height - 1 {
                    blocks[x][y][0] = true  // Only z=0 for 1 block high wall
                }
            }
        }
        
        // Create interesting structures throughout the larger 60x60 map
        
        // Large step pyramids in corners and edges
        // Each pyramid gets ramps on different faces with varying widths
        // Alternating between external and embedded ramps
        makeStepPyramid(x: 8, y: 8, size: 12, rampDirection: 0, rampWidth: 2, embeddedRamp: false)       // Top-left, south face, 2-wide, external
        makeStepPyramid(x: 40, y: 8, size: 10, rampDirection: 2, rampWidth: 1, embeddedRamp: true)       // Top-right, north face, 1-wide, embedded
        makeStepPyramid(x: 8, y: 40, size: 10, rampDirection: 3, rampWidth: 2, embeddedRamp: false)      // Bottom-left, east face, 2-wide, external
        makeStepPyramid(x: 42, y: 42, size: 8, rampDirection: 1, rampWidth: 1, embeddedRamp: true)       // Bottom-right, west face, 1-wide, embedded
        
        // Medium step pyramids scattered
        makeStepPyramid(x: 26, y: 26, size: 8, rampDirection: 0, rampWidth: 2, embeddedRamp: false)      // Center, south face, external
        makeStepPyramid(x: 15, y: 45, size: 6, rampDirection: 3, rampWidth: 1, embeddedRamp: true)       // East face, embedded
        makeStepPyramid(x: 48, y: 22, size: 6, rampDirection: 1, rampWidth: 1, embeddedRamp: false)      // West face, external
        
        // Wide step pyramids (less steep, shrink by 2 per side per level)
        makeWideStepPyramid(x: 25, y: 5, size: 12, rampDirection: 0, rampWidth: 2, embeddedRamp: false)   // Top area, south face, external
        makeWideStepPyramid(x: 3, y: 25, size: 10, rampDirection: 3, rampWidth: 1, embeddedRamp: true)    // Left side, east face, embedded
        makeWideStepPyramid(x: 45, y: 45, size: 8, rampDirection: 2, rampWidth: 2, embeddedRamp: false)   // Bottom-right, north face, external
        
        // Tall towers
        makeTower(x: 30, y: 18, height: 5, baseSize: 3)
        makeTower(x: 52, y: 52, height: 6, baseSize: 2)
        makeTower(x: 15, y: 52, height: 4, baseSize: 3)
        makeTower(x: 52, y: 28, height: 5, baseSize: 2)
        makeTower(x: 35, y: 40, height: 5, baseSize: 2)
        
        // Platforms (flat elevated areas)
        makePlatform(x: 38, y: 12, width: 8, depth: 6, height: 2)
        makePlatform(x: 12, y: 30, width: 6, depth: 8, height: 3)
        makePlatform(x: 48, y: 35, width: 7, depth: 7, height: 2)
        makePlatform(x: 22, y: 48, width: 8, depth: 6, height: 2)
        
        // Stairs connecting different levels
        makeStairs(x: 22, y: 45, length: 6, direction: 0)  // Going east
        makeStairs(x: 45, y: 52, length: 5, direction: 1)  // Going south
        makeStairs(x: 52, y: 30, length: 4, direction: 3)  // Going north
        makeStairs(x: 30, y: 10, length: 5, direction: 2)  // Going west
        
        // Many arches scattered throughout the larger map
        // Arches in top section
        makeArch(x: 12, y: 10)
        makeArch(x: 20, y: 5)
        makeArch(x: 35, y: 8)
        makeArch(x: 42, y: 12)
        makeArch(x: 50, y: 6)
        
        // Arches in middle section
        makeArch(x: 8, y: 22)
        makeArch(x: 18, y: 28)
        makeArch(x: 28, y: 25)
        makeArch(x: 38, y: 30)
        makeArch(x: 48, y: 22)
        makeArch(x: 52, y: 35)
        
        // Arches in bottom section
        makeArch(x: 12, y: 42)
        makeArch(x: 22, y: 48)
        makeArch(x: 32, y: 52)
        makeArch(x: 42, y: 45)
        makeArch(x: 50, y: 50)
        
        // Additional arches near edges
        makeArch(x: 5, y: 35)
        makeArch(x: 55, y: 15)
        makeArch(x: 45, y: 55)
        
        // Small pyramids for variety
        makePyramid(x: 38, y: 25)
        makePyramid(x: 25, y: 52)
        makePyramid(x: 50, y: 15)
        makePyramid(x: 15, y: 18)
        makePyramid(x: 42, y: 38)
    }
    
    func hasBlock(x: Int, y: Int, z: Int) -> Bool {
        guard x >= 0 && x < width && y >= 0 && y < height && z >= 0 && z < maxLevels else {
            return false
        }
        return blocks[x][y][z]
    }
}
