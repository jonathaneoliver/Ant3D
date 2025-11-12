#!/bin/bash

# Start the configuration server
cd "$(dirname "$0")/config-server"
echo "Starting Ant Attack 3D Configuration Server..."
echo ""
echo "Web UI: http://localhost:3000"
echo "API: http://localhost:3000/api/config"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

npm start
