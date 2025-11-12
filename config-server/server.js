const express = require('express');
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = 3000;

// Enable CORS for iOS app
app.use(cors());
app.use(express.json());

// Serve static files (HTML UI)
app.use(express.static(path.join(__dirname, 'public')));

// Configuration state
let config = {
  droneAngle: 45.0,       // Down angle of camera in degrees (10-90)
  droneDistance: 30.0,    // Distance of camera from ball (10-80)
  ambientLight: 0.5,      // Ambient light intensity (0-1)
  shadowsEnabled: false,  // Enable/disable shadows
  lastUpdated: Date.now()
};

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
  console.log(`   Sending: angle=${config.droneAngle}, distance=${config.droneDistance}, ambient=${config.ambientLight}, shadows=${config.shadowsEnabled}`);
  
  res.json(config);
});

// POST endpoint - Web UI updates this
app.post('/api/config', (req, res) => {
  const { droneAngle, droneDistance, ambientLight, shadowsEnabled } = req.body;
  const clientIP = req.ip || req.connection.remoteAddress;
  
  console.log(`\n🎛️  CONFIG UPDATE from ${clientIP}`);
  console.log(`   Previous: angle=${config.droneAngle}, distance=${config.droneDistance}, ambient=${config.ambientLight}, shadows=${config.shadowsEnabled}`);
  
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
  
  config.lastUpdated = Date.now();
  
  console.log(`   New:      angle=${config.droneAngle}, distance=${config.droneDistance}, ambient=${config.ambientLight}, shadows=${config.shadowsEnabled}`);
  console.log(`   Updated at: ${new Date(config.lastUpdated).toISOString()}\n`);
  
  res.json(config);
});

// Get machine hostname
const os = require('os');
const hostname = os.hostname();

app.listen(PORT, '0.0.0.0', () => {
  console.log('\n========================================');
  console.log('🚀 Config Server Started');
  console.log('========================================');
  console.log(`Listening on:     http://0.0.0.0:${PORT}`);
  console.log(`Web UI:           http://localhost:${PORT}`);
  console.log(`iOS Simulator:    http://localhost:${PORT}/api/config`);
  console.log(`iOS Device:       http://${hostname}:${PORT}/api/config`);
  console.log(`Machine hostname: ${hostname}`);
  console.log('========================================');
  console.log('Initial config:', config);
  console.log('========================================\n');
  console.log('Waiting for connections...\n');
});
