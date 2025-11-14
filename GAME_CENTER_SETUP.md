# Game Center Setup Guide for Ant Attack 3D

This guide walks you through setting up Game Center for your iOS game.

## ✅ What's Already Done

Your project already has:

1. **Game Center Entitlements** ✓
   - `AntAttack3D.entitlements` includes `com.apple.developer.game-center`
   - `AntAttack3DDebug.entitlements` includes `com.apple.developer.game-center`

2. **GameCenterManager.swift** ✓
   - Handles authentication
   - Submits scores to leaderboard
   - Loads leaderboard scores
   - Shows Game Center UI

3. **GKGameCenterConfiguration.plist** ✓
   - Local configuration file for testing
   - Defines leaderboard: `antattack3d_highscores`
   - Defines 4 achievements (see below)

4. **Bundle Identifier**: `com.jeoliver.AI-AntAttack3D`

## 📋 Next Steps: App Store Connect Setup

### Step 1: Create an App in App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Sign in with your Apple Developer account
3. Click **"My Apps"** → **"+"** → **"New App"**
4. Fill in:
   - **Platform**: iOS
   - **Name**: Ant Attack 3D
   - **Primary Language**: English
   - **Bundle ID**: Select `com.jeoliver.AI-AntAttack3D`
   - **SKU**: `antattack3d` (or any unique identifier)
5. Click **"Create"**

### Step 2: Enable Game Center

1. In your app's page, scroll to **"App Information"** section
2. Under **"General Information"**, find **"Game Center"**
3. Toggle **"Game Center"** to **ON**
4. Click **"Save"**

### Step 3: Configure the Leaderboard

1. Go to **"Services"** → **"Game Center"**
2. Click **"Leaderboards"** tab
3. Click **"+"** to add a new leaderboard
4. Select **"Single Leaderboard"**
5. Fill in the details:

   **Leaderboard Reference Name**: `High Scores`
   **Leaderboard ID**: `antattack3d_highscores` ⚠️ **Must match exactly!**
   
   **Score Format Type**: Integer
   **Score Submission Type**: Best Score
   **Sort Order**: High to Low
   **Score Range**: Minimum: 0, Maximum: 999999
   
   **Leaderboard Localization** (Add for at least one language):
   - **Language**: English (U.S.)
   - **Name**: High Scores
   - **Score Format**: 
     - Format: Integer
     - Suffix: pts (with a space before)
   - **Image**: (Optional) Upload a 512x512 image

6. Click **"Save"**

### Step 4: Configure Achievements (Optional)

The configuration file includes 4 achievements. For each one:

1. Go to **"Achievements"** tab
2. Click **"+"** to add a new achievement
3. Fill in:

#### Achievement 1: First Rescue
- **Achievement Reference Name**: First Rescue
- **Achievement ID**: `antattack3d_first_rescue`
- **Point Value**: 10
- **Hidden**: No
- **Achievable More Than Once**: No
- **Localization**:
  - **Title**: First Rescue
  - **Pre-earned Description**: Rescue your first hostage
  - **Earned Description**: You rescued your first hostage!
  - **Image**: 512x512 or 1024x1024 image (optional)

#### Achievement 2: Getting Started
- **Achievement ID**: `antattack3d_score_1000`
- **Title**: Getting Started
- **Point Value**: 20
- **Description**: Score 1,000 points

#### Achievement 3: Ant Warrior
- **Achievement ID**: `antattack3d_score_5000`
- **Title**: Ant Warrior
- **Point Value**: 50
- **Description**: Score 5,000 points

#### Achievement 4: Hero
- **Achievement ID**: `antattack3d_rescue_10`
- **Title**: Hero
- **Point Value**: 100
- **Description**: Rescue 10 hostages

### Step 5: Add Test Users (For Sandbox Testing)

1. Go to **"Users and Access"** → **"Sandbox Testers"**
2. Click **"+"** to add a tester
3. Fill in:
   - **First Name**, **Last Name**
   - **Email**: Use a unique email (can be fake, like `test1@example.com`)
   - **Password**: Create a password
   - **Region**: Select your region
4. Click **"Invite"**

## 🧪 Testing Game Center

### On Simulator (Limited Testing)
The simulator has limited Game Center support. You'll see:
- Status: "🎮 Simulator Only" (gray)
- Scores save locally via UserDefaults
- Game Center features won't work

### On Real Device (Full Testing)

1. **Sign Out of Your Personal Apple ID**:
   - Settings → [Your Name] → Sign Out (or just Game Center)

2. **Sign In with Sandbox Account**:
   - Settings → Game Center
   - Sign in with your sandbox test account
   - You may need to accept terms

3. **Run the App**:
   - Build and run on your device
   - You should see "🎮 ✓ Connected" in green
   - Play the game and achieve a score
   - Your score will submit to Game Center

4. **Verify the Leaderboard**:
   - Tap **"🎮 GAME CENTER"** button on title screen
   - You should see the Game Center leaderboard UI
   - Your score should appear

## 🐛 Troubleshooting

### Error: "Leaderboard not yet created in App Store Connect"
- **Solution**: Complete Step 3 above - the leaderboard ID must match exactly: `antattack3d_highscores`

### Error: "Authentication failed" or Code 3
- **In Simulator**: This is expected - use a real device
- **On Device**: 
  - Check you're signed into Game Center in Settings
  - Try signing out and back in
  - Use a sandbox test account, not your personal Apple ID

### Leaderboard Shows No Scores
- Wait a few minutes - scores can take time to propagate
- Make sure you submitted the score while authenticated
- Check console logs for "✅ [GameCenter] Score submitted successfully"

### Game Center Button Doesn't Work
- Check you're authenticated (green status indicator)
- Check entitlements are properly configured
- Verify the app is properly signed

## 📝 Current Leaderboard ID

Your game uses this leaderboard ID:
```
antattack3d_highscores
```

This is defined in:
- `GameCenterManager.swift` (line 18)
- `GKGameCenterConfiguration.plist`

**⚠️ Important**: The ID in App Store Connect **must match exactly** (case-sensitive).

## 🎮 How Game Center Works in Your Game

1. **App Launch**: GameCenterManager initializes and authenticates (AppDelegate3D.swift)
2. **Title Screen**: Shows connection status in top-right corner
3. **During Gameplay**: Scores are tracked
4. **Game Over**: 
   - Score is submitted to Game Center (if authenticated)
   - Score is always saved locally via UserDefaults
   - Leaderboard screen shows both local and Game Center scores
5. **Leaderboard Screen**: 
   - Shows local scores immediately
   - Loads Game Center scores asynchronously (if authenticated)
   - "🎮 FULL LEADERBOARD" button shows native Game Center UI

## 📦 Files Added/Modified

- ✅ `GKGameCenterConfiguration.plist` - Local Game Center config (added)
- ✅ `GameCenterManager.swift` - Manages Game Center integration (updated)
- ✅ `AppDelegate3D.swift` - Initializes Game Center on launch (updated)
- ✅ `TitleScene3D.swift` - Shows connection status (updated)
- ✅ `LeaderboardScene3D.swift` - Displays scores (updated)
- ✅ `AntAttack3D.entitlements` - Game Center capability (already had)

## 🚀 Publishing to App Store

Before submitting to the App Store:

1. ✅ Complete all App Store Connect setup above
2. ✅ Test thoroughly with sandbox accounts
3. ✅ Verify leaderboard works on real devices
4. ✅ Test achievements if implemented
5. ✅ Take screenshots for App Store listing
6. ✅ Fill out App Store metadata
7. ✅ Submit for review

**Note**: Game Center features are reviewed as part of your app review process.

## 📚 Additional Resources

- [Apple Game Center Documentation](https://developer.apple.com/game-center/)
- [GameKit Framework](https://developer.apple.com/documentation/gamekit)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)

## 🎯 Summary

✅ Your game is **ready for Game Center** on the code side!
⏳ Next step: Complete the **App Store Connect setup** (Steps 1-4 above)
🧪 Then: Test on a **real device** with a **sandbox account**

Good luck with your game! 🎮
