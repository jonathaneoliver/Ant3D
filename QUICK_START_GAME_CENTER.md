# Quick Start: Game Center Setup

## 🎯 TL;DR - What You Need to Do

Your game code is ready! You just need to:

1. **Go to App Store Connect** (https://appstoreconnect.apple.com)
2. **Create/Select your app** → Enable Game Center
3. **Add Leaderboard**: ID = `antattack3d_highscores`
4. **Test on real device** (Simulator won't work fully)

## 📱 Files Already Added

✅ `GKGameCenterConfiguration.plist` - Configuration file  
✅ `GameCenterManager.swift` - Updated with error handling  
✅ `TitleScene3D.swift` - Shows connection status  
✅ Entitlements enabled

## 🔑 Critical Information

**Bundle ID**: `com.jeoliver.AI-AntAttack3D`  
**Leaderboard ID**: `antattack3d_highscores` ⚠️ Must match exactly!

## 🧪 Quick Test

1. Build on **real iOS device** (not simulator)
2. Sign in to Game Center in Settings with sandbox account
3. Launch game - should see "🎮 ✓ Connected" (green)
4. Play and get a score
5. Tap "🎮 GAME CENTER" button to see leaderboard

## ⚠️ Common Issues

- **Simulator**: Will show "🎮 Simulator Only" - this is normal
- **Error Code 3**: Use real device, not simulator
- **"Leaderboard not found"**: Create it in App Store Connect

## 📖 Full Guide

See `GAME_CENTER_SETUP.md` for complete step-by-step instructions.
