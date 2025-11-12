# Configuration Server Setup

This project includes a configuration server that allows real-time adjustment of game parameters through a web interface.

## Server Files

The server is located in `config-server/`:
- `server.js` - Express server with REST API
- `package.json` - Node.js dependencies
- `public/index.html` - Web UI with sliders

## Setup Instructions

### 1. Install Node.js Dependencies

```bash
cd config-server
npm install
```

### 2. Start the Server

```bash
npm start
```

The server will start on `http://localhost:3000`

### 3. Open Web UI

Open your browser to `http://localhost:3000` to access the configuration interface with sliders for:
- **Drone Height**: Camera height above the ball (0-50)
- **Drone Distance**: Camera distance behind the ball (10-80)

### 4. Add ConfigManager.swift to Xcode Project

**IMPORTANT**: You need to manually add `AntAttack3D/ConfigManager.swift` to your Xcode project:

1. Open `AntAttack3D.xcodeproj` in Xcode
2. Right-click on the `AntAttack3D` folder in the Project Navigator
3. Select "Add Files to AntAttack3D..."
4. Navigate to and select `AntAttack3D/ConfigManager.swift`
5. Make sure "Copy items if needed" is checked
6. Click "Add"

### 5. Configure Network Access

#### For iOS Simulator:
The app is configured to connect to `http://localhost:3000/api/config` which works with the Simulator.

#### For Physical iOS Device:
You'll need to update the server URL in `ConfigManager.swift`:

1. Find your Mac's local IP address:
   ```bash
   ifconfig | grep "inet " | grep -v 127.0.0.1
   ```

2. Update the `serverURL` in `ConfigManager.swift`:
   ```swift
   private let serverURL = "http://YOUR_MAC_IP:3000/api/config"
   ```

3. Add App Transport Security exception to `Info.plist`:
   ```xml
   <key>NSAppTransportSecurity</key>
   <dict>
       <key>NSAllowsArbitraryLoads</key>
       <true/>
   </dict>
   ```

### 6. Run the App

1. Build and run the app in Xcode (Cmd+R)
2. The app will automatically start polling the config server every 0.5 seconds
3. Adjust sliders in the web UI and see the camera position update in real-time!

## Configuration Parameters

### Drone Height (0-50)
Controls how high the camera is positioned above the ball.
- **0**: Ground level (follows right behind the ball)
- **15**: Default height (good balance)
- **50**: Bird's eye view

### Drone Distance (10-80)
Controls how far behind the ball the camera is positioned.
- **10**: Very close (tight follow)
- **30**: Default distance (good visibility)
- **80**: Far back (wide view of surroundings)

## API Endpoints

### GET /api/config
Returns current configuration:
```json
{
  "droneHeight": 15.0,
  "droneDistance": 30.0,
  "lastUpdated": 1699999999999
}
```

### POST /api/config
Update configuration:
```json
{
  "droneHeight": 20.0,
  "droneDistance": 35.0
}
```

## Troubleshooting

### App not connecting to server
1. Check that the server is running (`npm start`)
2. Verify the server URL in `ConfigManager.swift`
3. Check Xcode console for connection errors
4. For physical devices, ensure Mac and iOS device are on the same network

### Sliders not affecting app
1. Check that config polling started (look for "ConfigManager: Starting to poll" in console)
2. Verify that `ConfigManager.swift` was properly added to the Xcode project
3. Check for any compilation errors in Xcode

### Server errors
1. Make sure port 3000 is not already in use
2. Check Node.js version (requires v14+)
3. Verify all dependencies installed: `npm install`
