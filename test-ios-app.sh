#!/bin/bash
# iOS App Testing Agent for Ant Attack 3D

DEVICE_NAME="Jonathans iPhone"
PROJECT_DIR="/Users/jonathanoliver/Ant3D"
APP_PATH="/Users/jonathanoliver/Library/Developer/Xcode/DerivedData/AntAttack3D-gdgxvudsihthulfhdrqkfxoeolib/Build/Products/Debug-iphoneos/AntAttack3D.app"
BUNDLE_ID="com.example.AntAttack3D"

echo "🎮 iOS App Testing Agent for Ant Attack 3D"
echo "=========================================="
echo ""

# Step 1: Check if device is connected and get its ID
echo "📱 Checking if $DEVICE_NAME is connected..."
DEVICE_ID=$(xcrun devicectl list devices 2>&1 | grep "$DEVICE_NAME" | awk '{print $3}')
if [ -n "$DEVICE_ID" ]; then
    echo "✅ Device found: $DEVICE_NAME ($DEVICE_ID)"
else
    echo "❌ Device not found. Please connect your iPhone."
    exit 1
fi

# Step 2: Build the app
echo ""
echo "🔨 Building Ant Attack 3D for $DEVICE_NAME..."
cd "$PROJECT_DIR"
xcodebuild -project AntAttack3D.xcodeproj \
    -scheme AntAttack3D \
    -configuration Debug \
    -destination "id=$DEVICE_ID" \
    build 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:"

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi
echo "✅ Build succeeded"

# Step 3: Install the app
echo ""
echo "📲 Installing app on $DEVICE_NAME..."
INSTALL_OUTPUT=$(xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH" 2>&1)
if echo "$INSTALL_OUTPUT" | grep -q "App installed"; then
    echo "✅ App installed successfully"
else
    echo "⚠️ Install may have issues:"
    echo "$INSTALL_OUTPUT" | tail -5
fi

# Step 4: Launch the app
echo ""
echo "🚀 Launching Ant Attack 3D..."
LAUNCH_OUTPUT=$(xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID" 2>&1)
if echo "$LAUNCH_OUTPUT" | grep -q "Launched application"; then
    echo "✅ App launched successfully!"
else
    echo "⚠️ Launch command completed with:"
    echo "$LAUNCH_OUTPUT" | tail -5
    echo ""
    echo "💡 If launch failed, try manually tapping the app icon on your iPhone"
fi

# Step 5: Stream logs
echo ""
echo "📋 Streaming console logs (press Ctrl+C to stop)..."
echo "Filtering for: 🎮 🎬 ✅ ❌ 💀 🏆 ℹ️"
echo "=========================================="
echo ""

xcrun devicectl device log stream --device "$DEVICE_ID" 2>&1 | grep -E "AntAttack3D|🎮|🎬|✅|❌|💀|🏆|ℹ️"
