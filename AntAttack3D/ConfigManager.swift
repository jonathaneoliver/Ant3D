import Foundation
import os.log

// Configuration model matching server response
struct GameConfig: Codable {
    var droneAngle: Float       // Down angle in degrees (10-90)
    var droneDistance: Float    // Distance from ball
    var ambientLight: Float
    var shadowsEnabled: Bool
    var orbitSearchDelay: Float // Delay in seconds before starting orbit search when ball is hidden (default: 10.0)
    var showDebugHUD: Bool      // Show debug HUD elements (connection status, visibility, distance) - defaults to false
    var showsStatistics: Bool   // Show FPS and performance stats - defaults to false
    var fogStartDistance: Float // Distance where fog starts (default: 40.0)
    var fogEndDistance: Float   // Distance where fog ends (default: 80.0)
    var lastUpdated: Int64
}

// Map data model matching server map format
struct MapData: Codable {
    var name: String
    var width: Int
    var height: Int
    var maxLevels: Int
    var blocks: [[[Bool]]]
    var ramps: [RampData]
    var createdAt: String?
    
    // Optional height map for bitmap-encoded maps (Ant Attack format)
    // Each value 0-63 is a 9-bit bitmap where bit N indicates a block at Z-level N
    var heightMap: [[Int]]?
}

struct RampData: Codable {
    var x: Int
    var y: Int
    var z: Int
    var direction: Int
    var width: Int
    var height: Int
    var isShallow: Bool
}

// Configuration manager that polls the server
class ConfigManager {
    static let shared = ConfigManager()
    
    // Server URL - hardcoded to MacBook-Pro.local
    private var serverURL: String {
        return "http://MacBook-Pro.local:3000/api/config"
    }
    
    private var serverBaseURL: String {
        return "http://MacBook-Pro.local:3000"
    }
    
    // Current configuration
    private(set) var config = GameConfig(
        droneAngle: 45.0,
        droneDistance: 30.0,
        ambientLight: 0.5,
        shadowsEnabled: false,
        orbitSearchDelay: 10.0,  // Default: wait 10 seconds before starting orbit search
        showDebugHUD: false,     // Default: debug HUD hidden
        showsStatistics: false,  // Default: FPS stats hidden
        fogStartDistance: 40.0,  // Default: fog starts at 40 units
        fogEndDistance: 80.0,    // Default: fog ends at 80 units
        lastUpdated: 0
    )
    
    // Connection status
    private(set) var isConnected = false
    private var lastSuccessTime: Date?
    
    // Polling timer
    private var timer: Timer?
    private let pollInterval: TimeInterval = 0.5  // Poll every 0.5 seconds
    
    // Callbacks
    var onConfigUpdate: ((GameConfig) -> Void)?
    var onConnectionStatusChanged: ((Bool, String) -> Void)?
    
    private init() {}
    
    // Start polling the config server
    func startPolling() {
        let url = serverURL
        print("========================================")
        print("🌐 ConfigManager: Starting to poll server")
        print("🌐 Server URL: \(url)")
        print("========================================")
        NSLog("🌐 ConfigManager: Starting to poll server at %@", url)
        os_log("🌐 ConfigManager: Starting to poll server at %@", type: .error, url)
        
        // Fetch immediately
        fetchConfig()
        
        // Then poll on interval
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.fetchConfig()
        }
    }
    
    // Stop polling
    func stopPolling() {
        print("ConfigManager: Stopping polling")
        timer?.invalidate()
        timer = nil
    }
    
    // Fetch config from server
    private func fetchConfig() {
        let urlString = serverURL
        guard let url = URL(string: urlString) else {
            updateConnectionStatus(false)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                self?.updateConnectionStatus(false)
                return
            }
            
            guard let data = data else {
                self?.updateConnectionStatus(false)
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let newConfig = try decoder.decode(GameConfig.self, from: data)
                
                // Update connection status
                self?.updateConnectionStatus(true)
                
                // Only update if config actually changed
                if self?.hasConfigChanged(newConfig) == true {
                    DispatchQueue.main.async {
                        self?.config = newConfig
                        print("ConfigManager: 🔄 Config changed - angle: \(newConfig.droneAngle), distance: \(newConfig.droneDistance), ambient: \(newConfig.ambientLight), shadows: \(newConfig.shadowsEnabled), showDebugHUD: \(newConfig.showDebugHUD)")
                        self?.onConfigUpdate?(newConfig)
                    }
                }
            } catch {
                self?.updateConnectionStatus(false)
            }
        }
        
        task.resume()
    }
    
    // Update connection status
    private func updateConnectionStatus(_ connected: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if connected {
                self.lastSuccessTime = Date()
            }
            
            let wasConnected = self.isConnected
            self.isConnected = connected
            
            // Notify if status changed
            if wasConnected != connected {
                let serverInfo = self.serverURL.replacingOccurrences(of: "/api/config", with: "")
                print("ConfigManager: 🔌 Connection status changed: \(connected ? "CONNECTED" : "DISCONNECTED") to \(serverInfo)")
                self.onConnectionStatusChanged?(connected, serverInfo)
            }
        }
    }
    
    // Check if config has meaningfully changed
    private func hasConfigChanged(_ newConfig: GameConfig) -> Bool {
        return abs(newConfig.droneAngle - config.droneAngle) > 0.01 ||
               abs(newConfig.droneDistance - config.droneDistance) > 0.01 ||
               abs(newConfig.ambientLight - config.ambientLight) > 0.01 ||
               abs(newConfig.orbitSearchDelay - config.orbitSearchDelay) > 0.01 ||
               abs(newConfig.fogStartDistance - config.fogStartDistance) > 0.01 ||
               abs(newConfig.fogEndDistance - config.fogEndDistance) > 0.01 ||
               newConfig.shadowsEnabled != config.shadowsEnabled ||
               newConfig.showDebugHUD != config.showDebugHUD ||
               newConfig.showsStatistics != config.showsStatistics
    }
    
    // MARK: - Map Loading
    
    // Fetch list of available maps
    func fetchMapList(completion: @escaping (Result<[MapData], Error>) -> Void) {
        let urlString = "\(serverBaseURL)/api/maps"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "ConfigManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "ConfigManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let maps = try decoder.decode([MapData].self, from: data)
                DispatchQueue.main.async {
                    completion(.success(maps))
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    // Fetch specific map by name
    func fetchMap(name: String, completion: @escaping (Result<MapData, Error>) -> Void) {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        let urlString = "\(serverBaseURL)/api/maps/\(encodedName)"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "ConfigManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        print("📥 Loading map: \(name) from \(urlString)")
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Error loading map: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "ConfigManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let mapData = try decoder.decode(MapData.self, from: data)
                print("✅ Map loaded: \(mapData.name), size: \(mapData.width)x\(mapData.height)x\(mapData.maxLevels)")
                DispatchQueue.main.async {
                    completion(.success(mapData))
                }
            } catch {
                print("❌ Error decoding map: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    // Load bundled Ant Attack Original map from app resources
    func loadBundledAntAttackMap() -> MapData? {
        guard let url = Bundle.main.url(forResource: "ant_attack_original", withExtension: "json") else {
            print("❌ Could not find bundled ant_attack_original.json in app bundle")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let mapData = try decoder.decode(MapData.self, from: data)
            print("✅ Loaded bundled Ant Attack Original map: \(mapData.width)x\(mapData.height)x\(mapData.maxLevels)")
            return mapData
        } catch {
            print("❌ Error loading bundled map: \(error.localizedDescription)")
            return nil
        }
    }
}
