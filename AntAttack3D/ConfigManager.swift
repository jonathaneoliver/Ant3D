import Foundation
import os.log

// Configuration model matching server response
struct GameConfig: Codable {
    var droneAngle: Float       // Down angle in degrees (10-90)
    var droneDistance: Float    // Distance from ball
    var ambientLight: Float
    var shadowsEnabled: Bool
    var lastUpdated: Int64
}

// Configuration manager that polls the server
class ConfigManager {
    static let shared = ConfigManager()
    
    // Server URL - hardcoded to MacBook-Pro.local
    private var serverURL: String {
        return "http://MacBook-Pro.local:3000/api/config"
    }
    
    // Current configuration
    private(set) var config = GameConfig(
        droneAngle: 45.0,
        droneDistance: 30.0,
        ambientLight: 0.5,
        shadowsEnabled: false,
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
        FileLogger.shared.log("🌐 ConfigManager: Starting to poll \(url)")
        
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
                        print("ConfigManager: 🔄 Config changed - angle: \(newConfig.droneAngle), distance: \(newConfig.droneDistance), ambient: \(newConfig.ambientLight), shadows: \(newConfig.shadowsEnabled)")
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
               newConfig.shadowsEnabled != config.shadowsEnabled
    }
}
