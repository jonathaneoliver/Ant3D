# Agent Instructions for Ant Attack 3D

## Project Overview
iOS SceneKit 3D game implementing Ant Attack-style isometric city view. Built with Swift 5.0+, targeting iOS 15.0+. Uses orthographic camera projection for pseudo-isometric rendering. Originally ported from macOS to iOS.

## Build & Run Commands
```bash
# Build for iOS Simulator
xcodebuild -project AntAttack3D.xcodeproj -scheme AntAttack3D -configuration Debug -sdk iphonesimulator build

# Clean build for iOS Simulator
xcodebuild -project AntAttack3D.xcodeproj -scheme AntAttack3D -sdk iphonesimulator clean build

# Run in iOS Simulator (after building)
open -a Simulator
xcrun simctl install booted /Users/jonathanoliver/Library/Developer/Xcode/DerivedData/AntAttack3D-*/Build/Products/Debug-iphonesimulator/AntAttack3D.app
xcrun simctl launch booted com.example.AntAttack3D

# Or run directly in Xcode
# Product > Destination > Select iOS Simulator
# Product > Run (Cmd+R)
```

## Code Style Guidelines

### File Organization
- **Source files**: AntAttack3D/*.swift (flat structure)
- **Naming**: Suffix classes with "3D" (GameScene3D, CityMap3D, GameViewController3D)

### Swift Conventions
- **Imports**: SceneKit for 3D, Foundation for data structures, UIKit for iOS UI
- **Types**: Explicit type annotations for class properties, inference OK for local variables
  - **SceneKit positions**: Use `Float` for SCNVector3 components (iOS requirement), not `CGFloat`
- **Naming**: camelCase for properties/methods, PascalCase for classes
- **Access control**: No explicit modifiers (internal by default), use private for helpers

### Architecture Patterns
- **App lifecycle**: AppDelegate uses @main, creates window programmatically in application(_:didFinishLaunchingWithOptions:)
- **View hierarchy**: AppDelegate → UIWindow → GameViewController3D → SCNView → GameScene3D
- **Scene management**: GameScene3D inherits from SCNScene, handles 3D world setup
- **Data structures**: 3D arrays for voxel-based city map `[[[Bool]]]` indexed as `[x][y][z]`
- **Camera setup**: Orthographic projection at 45° angle for isometric view, allowsCameraControl=true for interaction
- **Materials**: Lambert lighting model, different colors for ground (tan) vs elevated blocks (blue)
- **Orientation**: Landscape-only mode configured via Info.plist (UISupportedInterfaceOrientations)

### View Controller Requirements
- **UIViewController**: GameViewController3D inherits from UIViewController (no custom initializers needed)
- **viewDidLoad**: Create SCNView, configure camera controls and rendering options
- **Status bar**: Hidden via prefersStatusBarHidden property
- **Orientation**: supportedInterfaceOrientations returns .landscape for landscape-only mode

### Error Handling
- Guard statements for array bounds checking before accessing city map blocks  
- Optional chaining for scene view operations
- Print statements for debugging lifecycle methods

## iOS Conversion Notes
This project was successfully ported from macOS to iOS. Key changes made:

### Framework Changes
- **AppDelegate**: NSApplicationDelegate → UIApplicationDelegate, NSWindow → UIWindow
- **GameViewController**: NSViewController → UIViewController, removed custom initializers
- **Colors**: NSColor → UIColor throughout
- **Autoresizing**: Changed mask from `.width, .height` to `.flexibleWidth, .flexibleHeight`

### Type Conversions
- **SCNVector3**: Changed position values from `CGFloat` to `Float` (iOS requirement)

### Project Configuration
- **SDK**: Changed from macosx to iphoneos
- **Deployment target**: iOS 15.0+ (was macOS 13.0+)
- **Device family**: iPhone and iPad (TARGETED_DEVICE_FAMILY = "1,2")
- **Runpath**: @executable_path/Frameworks (iOS standard)

### Info.plist Changes
- Removed macOS-specific keys (LSMinimumSystemVersion, NSMainStoryboardFile, NSPrincipalClass, CFBundleIconFile)
- Added iOS-specific keys: LSRequiresIPhoneOS, UIStatusBarHidden, UISupportedInterfaceOrientations
- No storyboard used (programmatic UI creation)

## Notes from copilot-instructions.md
The copilot-instructions.md references an iOS Asteroids game - this appears to be from a different project and should be ignored for this iOS 3D codebase.
