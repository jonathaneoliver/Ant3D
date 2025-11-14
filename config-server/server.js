const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs').promises;

const app = express();
const PORT = 3000;

// Enable CORS for iOS app
app.use(cors());
app.use(express.json({ limit: '50mb' })); // Increase limit for large map data

// Serve static files (HTML UI)
app.use(express.static(path.join(__dirname, 'public')));

// Configuration state
let config = {
  droneAngle: 45.0,       // Down angle of camera in degrees (10-90)
  droneDistance: 30.0,    // Distance of camera from ball (10-80)
  ambientLight: 0.5,      // Ambient light intensity (0-1)
  shadowsEnabled: false,  // Enable/disable shadows
  orbitSearchDelay: 10.0, // Delay in seconds before starting orbit search when ball is hidden
  showDebugHUD: false,    // Show debug HUD elements (connection status, visibility, distance)
  showsStatistics: false, // Show FPS statistics overlay
  fogStartDistance: 40.0, // Fog start distance (10-100)
  fogEndDistance: 80.0,   // Fog end distance (20-150)
  lastUpdated: Date.now()
};

// Map storage directory
const MAPS_DIR = path.join(__dirname, 'maps');

// Initialize maps directory
(async () => {
  try {
    await fs.mkdir(MAPS_DIR, { recursive: true });
    console.log(`Maps directory initialized at: ${MAPS_DIR}`);
  } catch (err) {
    console.error('Failed to create maps directory:', err);
  }
})();

// Middleware to log all requests
app.use((req, res, next) => {
  const timestamp = new Date().toISOString();
  const clientIP = req.ip || req.connection.remoteAddress;
  console.log(`[${timestamp}] ${req.method} ${req.path} from ${clientIP}`);
  next();
});

// GET endpoint - iOS app polls this
app.get('/api/config', (req, res) => {
  const clientIP = req.ip || req.connection.remoteAddress;
  const userAgent = req.get('User-Agent') || 'Unknown';
  
  console.log(`📱 App polling config - IP: ${clientIP}, UA: ${userAgent}`);
  console.log(`   Sending: angle=${config.droneAngle}, distance=${config.droneDistance}, ambient=${config.ambientLight}, shadows=${config.shadowsEnabled}, orbitDelay=${config.orbitSearchDelay}, showDebugHUD=${config.showDebugHUD}, stats=${config.showsStatistics}, fogStart=${config.fogStartDistance}, fogEnd=${config.fogEndDistance}`);
  
  res.json(config);
});

// POST endpoint - Web UI updates this
app.post('/api/config', (req, res) => {
  const { droneAngle, droneDistance, ambientLight, shadowsEnabled, orbitSearchDelay, showDebugHUD, showsStatistics, fogStartDistance, fogEndDistance } = req.body;
  const clientIP = req.ip || req.connection.remoteAddress;
  
  console.log(`\n🎛️  CONFIG UPDATE from ${clientIP}`);
  console.log(`   Previous: angle=${config.droneAngle}, distance=${config.droneDistance}, ambient=${config.ambientLight}, shadows=${config.shadowsEnabled}, orbitDelay=${config.orbitSearchDelay}, showDebugHUD=${config.showDebugHUD}, stats=${config.showsStatistics}, fogStart=${config.fogStartDistance}, fogEnd=${config.fogEndDistance}`);
  
  if (droneAngle !== undefined) {
    config.droneAngle = parseFloat(droneAngle);
  }
  if (droneDistance !== undefined) {
    config.droneDistance = parseFloat(droneDistance);
  }
  if (ambientLight !== undefined) {
    config.ambientLight = parseFloat(ambientLight);
  }
  if (shadowsEnabled !== undefined) {
    config.shadowsEnabled = Boolean(shadowsEnabled);
  }
  if (orbitSearchDelay !== undefined) {
    config.orbitSearchDelay = parseFloat(orbitSearchDelay);
  }
  if (showDebugHUD !== undefined) {
    config.showDebugHUD = Boolean(showDebugHUD);
  }
  if (showsStatistics !== undefined) {
    config.showsStatistics = Boolean(showsStatistics);
  }
  if (fogStartDistance !== undefined) {
    config.fogStartDistance = parseFloat(fogStartDistance);
  }
  if (fogEndDistance !== undefined) {
    config.fogEndDistance = parseFloat(fogEndDistance);
  }
  
  config.lastUpdated = Date.now();
  
  console.log(`   New:      angle=${config.droneAngle}, distance=${config.droneDistance}, ambient=${config.ambientLight}, shadows=${config.shadowsEnabled}, orbitDelay=${config.orbitSearchDelay}, showDebugHUD=${config.showDebugHUD}, stats=${config.showsStatistics}, fogStart=${config.fogStartDistance}, fogEnd=${config.fogEndDistance}`);
  console.log(`   Updated at: ${new Date(config.lastUpdated).toISOString()}\n`);
  
  res.json(config);
});

// MAP ENDPOINTS

// Save map
app.post('/api/maps', async (req, res) => {
  try {
    const mapData = req.body;
    const clientIP = req.ip || req.connection.remoteAddress;
    
    if (!mapData.name) {
      return res.status(400).send('Map name is required');
    }
    
    const filename = `${mapData.name.replace(/[^a-z0-9_-]/gi, '_')}.json`;
    const filepath = path.join(MAPS_DIR, filename);
    
    await fs.writeFile(filepath, JSON.stringify(mapData, null, 2));
    
    console.log(`\n💾 MAP SAVED from ${clientIP}`);
    console.log(`   Name: ${mapData.name}`);
    console.log(`   File: ${filename}`);
    console.log(`   Size: ${mapData.width}x${mapData.height}x${mapData.maxLevels}`);
    console.log(`   Blocks: ${countBlocks(mapData.blocks)}`);
    console.log(`   Ramps: ${mapData.ramps.length}\n`);
    
    res.json({ success: true, filename });
  } catch (err) {
    console.error('Error saving map:', err);
    res.status(500).send('Failed to save map: ' + err.message);
  }
});

// Get list of all maps
app.get('/api/maps', async (req, res) => {
  try {
    const files = await fs.readdir(MAPS_DIR);
    const jsonFiles = files.filter(f => f.endsWith('.json'));
    
    const maps = [];
    for (const file of jsonFiles) {
      const filepath = path.join(MAPS_DIR, file);
      const content = await fs.readFile(filepath, 'utf8');
      const mapData = JSON.parse(content);
      maps.push({
        name: mapData.name,
        filename: file,
        width: mapData.width,
        height: mapData.height,
        maxLevels: mapData.maxLevels,
        blocks: countBlocks(mapData.blocks),
        ramps: mapData.ramps.length,
        createdAt: mapData.createdAt
      });
    }
    
    console.log(`📋 Map list requested - ${maps.length} maps available`);
    res.json(maps);
  } catch (err) {
    console.error('Error reading maps:', err);
    res.status(500).send('Failed to read maps: ' + err.message);
  }
});

// Get specific map
app.get('/api/maps/:name', async (req, res) => {
  try {
    const mapName = req.params.name;
    const filename = `${mapName.replace(/[^a-z0-9_-]/gi, '_')}.json`;
    const filepath = path.join(MAPS_DIR, filename);
    
    const content = await fs.readFile(filepath, 'utf8');
    const mapData = JSON.parse(content);
    
    console.log(`\n📥 MAP LOADED: ${mapData.name}`);
    console.log(`   Blocks: ${countBlocks(mapData.blocks)}, Ramps: ${mapData.ramps.length}\n`);
    
    res.json(mapData);
  } catch (err) {
    console.error('Error loading map:', err);
    res.status(404).send('Map not found');
  }
});

// Helper function to count blocks
function countBlocks(blocks) {
  let count = 0;
  if (blocks) {
    for (let x = 0; x < blocks.length; x++) {
      for (let y = 0; y < blocks[x].length; y++) {
        for (let z = 0; z < blocks[x][y].length; z++) {
          if (blocks[x][y][z]) count++;
        }
      }
    }
  }
  return count;
}

// Get machine hostname
const os = require('os');
const hostname = os.hostname();

app.listen(PORT, '0.0.0.0', () => {
  console.log('\n========================================');
  console.log('🚀 Config Server Started');
  console.log('========================================');
  console.log(`Listening on:     http://0.0.0.0:${PORT}`);
  console.log(`Web UI:           http://localhost:${PORT}`);
  console.log(`Level Editor:     http://localhost:${PORT}/editor.html`);
  console.log(`iOS Simulator:    http://localhost:${PORT}/api/config`);
  console.log(`iOS Device:       http://${hostname}:${PORT}/api/config`);
  console.log(`Machine hostname: ${hostname}`);
  console.log('========================================');
  console.log('Initial config:', config);
  console.log('========================================\n');
  console.log('Waiting for connections...\n');
});
