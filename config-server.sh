#!/bin/bash

# Configuration server control script
SCRIPT_DIR="$(dirname "$0")"
CONFIG_DIR="$SCRIPT_DIR/config-server"
PID_FILE="$SCRIPT_DIR/.config-server.pid"

case "$1" in
    start)
        # Check if server is already running
        if [ -f "$PID_FILE" ]; then
            PID=$(cat "$PID_FILE")
            if ps -p $PID > /dev/null 2>&1; then
                echo "Configuration server is already running (PID: $PID)"
                echo "Web UI: http://localhost:3000"
                exit 1
            else
                # Stale PID file, remove it
                rm -f "$PID_FILE"
            fi
        fi
        
        # Start the server
        cd "$CONFIG_DIR"
        echo "Starting Ant Attack 3D Configuration Server with auto-reload..."
        echo ""
        echo "Web UI: http://localhost:3000"
        echo "API: http://localhost:3000/api/config"
        echo "Level Editor: http://localhost:3000/editor.html"
        echo ""
        echo "Auto-reload enabled - changes to server.js and public/ will restart the server"
        echo ""
        
        # Start in background and save PID using nodemon for auto-reload
        npm run dev > /dev/null 2>&1 &
        SERVER_PID=$!
        echo $SERVER_PID > "$PID_FILE"
        echo "Server started (PID: $SERVER_PID)"
        echo "Use './config-server.sh stop' to stop the server"
        ;;
        
    stop)
        if [ ! -f "$PID_FILE" ]; then
            echo "Configuration server is not running (no PID file found)"
            exit 1
        fi
        
        PID=$(cat "$PID_FILE")
        if ps -p $PID > /dev/null 2>&1; then
            echo "Stopping configuration server (PID: $PID)..."
            kill $PID
            rm -f "$PID_FILE"
            echo "Server stopped"
        else
            echo "Configuration server is not running (PID $PID not found)"
            rm -f "$PID_FILE"
        fi
        ;;
        
    status)
        if [ -f "$PID_FILE" ]; then
            PID=$(cat "$PID_FILE")
            if ps -p $PID > /dev/null 2>&1; then
                echo "Configuration server is running (PID: $PID)"
                echo "Web UI: http://localhost:3000"
            else
                echo "Configuration server is not running (stale PID file)"
                rm -f "$PID_FILE"
            fi
        else
            echo "Configuration server is not running"
        fi
        ;;
        
    cleanup)
        FORCE_MODE=false
        if [ "$2" = "-force" ] || [ "$2" = "--force" ]; then
            FORCE_MODE=true
            echo "========================================"
            echo "  Config Server Cleanup - FORCE MODE"
            echo "========================================"
        else
            echo "========================================"
            echo "  Config Server Cleanup - Port 3000"
            echo "========================================"
        fi
        echo ""
        
        # Check PID file first
        if [ -f "$PID_FILE" ]; then
            PID=$(cat "$PID_FILE")
            echo "📄 Found PID file: $PID_FILE"
            echo "   Recorded PID: $PID"
            if ps -p $PID > /dev/null 2>&1; then
                CMD=$(ps -p $PID -o command= 2>/dev/null)
                echo "   Status: Process is RUNNING"
                echo "   Command: $CMD"
            else
                echo "   Status: Process NOT RUNNING (stale PID file)"
            fi
            echo ""
        else
            echo "📄 No PID file found at: $PID_FILE"
            echo ""
        fi
        
        # Find all processes on port 3000
        echo "🔍 Checking port 3000 for active processes..."
        LSOF_OUTPUT=$(lsof -i:3000 2>/dev/null)
        
        if [ -z "$LSOF_OUTPUT" ]; then
            echo "   ✅ Port 3000 is FREE - no processes found"
            echo ""
            rm -f "$PID_FILE"
            echo "🧹 Cleaned up PID file"
            echo ""
            echo "✨ Cleanup complete - port is available"
            exit 0
        fi
        
        echo "   ⚠️  Port 3000 is IN USE"
        echo ""
        echo "📊 Detailed port usage:"
        echo "----------------------------------------"
        echo "$LSOF_OUTPUT" | head -1  # Header
        echo "----------------------------------------"
        echo "$LSOF_OUTPUT" | tail -n +2  # Data rows
        echo "----------------------------------------"
        echo ""
        
        # Extract PIDs from lsof output
        PIDS=$(echo "$LSOF_OUTPUT" | tail -n +2 | awk '{print $2}' | sort -u)
        
        # Check each PID for config-server match
        echo "🔎 Analyzing processes..."
        KILLED=0
        CONFIG_SERVER_FOUND=false
        
        for PID in $PIDS; do
            CMD=$(ps -p $PID -o command= 2>/dev/null)
            USER=$(ps -p $PID -o user= 2>/dev/null)
            
            echo ""
            echo "   PID: $PID"
            echo "   User: $USER"
            echo "   Command: $CMD"
            
            if echo "$CMD" | grep -q "config-server"; then
                CONFIG_SERVER_FOUND=true
                echo "   Match: ✅ This IS a config-server process"
                echo "   Action: Killing process..."
                
                if kill $PID 2>/dev/null; then
                    echo "   Result: ✅ Successfully killed PID $PID"
                    KILLED=$((KILLED + 1))
                    sleep 0.5  # Give it time to die
                else
                    echo "   Result: ❌ Failed to kill PID $PID (may need sudo)"
                fi
            elif [ "$FORCE_MODE" = true ]; then
                echo "   Match: ❌ This is NOT a config-server process"
                echo "   Action: 💥 FORCE MODE - Killing anyway..."
                
                if kill $PID 2>/dev/null; then
                    echo "   Result: ✅ Successfully killed PID $PID"
                    KILLED=$((KILLED + 1))
                    sleep 0.5  # Give it time to die
                else
                    echo "   Result: ❌ Failed to kill PID $PID (may need sudo)"
                fi
            else
                echo "   Match: ❌ This is NOT a config-server process"
                echo "   Action: Leaving process untouched"
                echo "   Hint: Use '-force' to kill ALL processes on port 3000"
            fi
        done
        
        echo ""
        echo "========================================"
        
        # Clean up PID file
        if [ -f "$PID_FILE" ]; then
            rm -f "$PID_FILE"
            echo "🧹 Removed PID file: $PID_FILE"
        fi
        
        echo ""
        if [ $KILLED -gt 0 ]; then
            if [ "$FORCE_MODE" = true ]; then
                echo "✅ FORCE cleanup complete: Killed $KILLED process(es) on port 3000"
            else
                echo "✅ Cleanup complete: Killed $KILLED config-server process(es)"
            fi
        elif [ "$CONFIG_SERVER_FOUND" = false ]; then
            echo "⚠️  Cleanup complete: No config-server processes found"
            if [ "$FORCE_MODE" = false ]; then
                echo "   Port 3000 is in use by OTHER processes (see details above)"
                echo "   💡 Use './config-server.sh cleanup -force' to kill ALL processes"
            fi
        else
            echo "❌ Cleanup incomplete: Found config-server but failed to kill"
        fi
        echo ""
        
        # Final port check
        if lsof -i:3000 > /dev/null 2>&1; then
            echo "📍 Port 3000 status: STILL IN USE"
            if [ "$FORCE_MODE" = false ]; then
                echo "   💡 Try: ./config-server.sh cleanup -force"
            fi
        else
            echo "📍 Port 3000 status: NOW FREE"
        fi
        echo ""
        ;;
        
    *)
        echo "Usage: $0 {start|stop|status|cleanup}"
        echo ""
        echo "Commands:"
        echo "  start          - Start the configuration server"
        echo "  stop           - Stop the configuration server"
        echo "  status         - Check if the server is running"
        echo "  cleanup        - Kill config-server processes on port 3000"
        echo "  cleanup -force - Kill ALL processes on port 3000 (regardless of type)"
        exit 1
        ;;
esac
