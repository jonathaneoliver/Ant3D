# Game UI Layout - Landscape Mode

## Overview
The game UI now uses a **three-column layout** with the 3D game view centered and HUD elements flanking it on both sides.

## Layout Structure

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         iPhone/iPad Landscape View                       │
├──────────────┬────────────────────────────────────┬─────────────────────┤
│              │                                    │                     │
│  LEFT SIDE   │         3D GAME VIEW              │    RIGHT SIDE       │
│  (180px)     │         (centered)                 │    (200px)          │
│              │                                    │                     │
│  ┌────────┐  │  ╔═══════════════════════════╗    │   ┌─────────────┐  │
│  │   ⏳   │  │  ║                           ║    │   │    MAP      │  │
│  │ Server │  │  ║                           ║    │   │             │  │
│  └────────┘  │  ║                           ║    │   │  ● ● ●      │  │
│              │  ║                           ║    │   │    ◯         │  │
│  ┌────────┐  │  ║     Isometric 3D City     ║    │   │             │  │
│  │   🎯   │  │  ║                           ║    │   │             │  │
│  │VISIBLE │  │  ║                           ║    │   │             │  │
│  └────────┘  │  ║                           ║    │   │             │  │
│              │  ║                           ║    │   └─────────────┘  │
│  ┌────────┐  │  ║                           ║    │                     │
│  │   📏   │  │  ║                           ║    │                     │
│  │Dist:30 │  │  ║                           ║    │                     │
│  └────────┘  │  ║                           ║    │                     │
│              │  ║                           ║    │                     │
│  ┌────────┐  │  ║                           ║    │                     │
│  │   💙   │  │  ║                           ║    │                     │
│  │Remain: │  │  ║                           ║    │                     │
│  │  3/5   │  │  ║                           ║    │                     │
│  └────────┘  │  ║                           ║    │                     │
│              │  ║                           ║    │                     │
│  ┌────────┐  │  ╚═══════════════════════════╝    │                     │
│  │   🏆   │  │                                    │                     │
│  │Score:  │  │         60fps ⬥ 29 ▲ 26.8K        │                     │
│  │  5000  │  │                                    │                     │
│  └────────┘  │                                    │                     │
│              │                                    │                     │
│  ┌────────┐  │                                    │                     │
│  │   🎮   │  │                                    │                     │
│  │Level: 2│  │                                    │                     │
│  └────────┘  │                                    │                     │
│              │                                    │                     │
└──────────────┴────────────────────────────────────┴─────────────────────┘
```

## Components

### Left Side (180px width)
All HUD elements positioned vertically in left margin:

1. **Connection Status** (80×50)
   - Server connection indicator
   - Shows green ● when connected, red ○ when disconnected
   - Debug only (hidden by default)

2. **Ball Visibility** (100×60)
   - Shows if player ball is visible from camera
   - 🎯 VISIBLE (green) or ⚠️ HIDDEN (red)
   - Debug only (hidden by default)

3. **Distance** (100×60)
   - Camera distance from player
   - 📏 Dist: XX.X
   - Debug only (hidden by default)

4. **Hostages Remaining** (120×70)
   - 💙 Remain: X/Y
   - Changes color: yellow (none saved) → cyan (some saved) → green (all saved)
   - Always visible

5. **Score** (120×60)
   - 🏆 Score: XXXXX
   - Yellow text
   - Always visible

6. **Level** (120×60)
   - 🎮 Level: X
   - Cyan text
   - Always visible

### Center - 3D Game View
- **SceneKit view** with isometric 3D city
- **Margins**: 180px left, 200px right
- **FPS counter** at bottom (showsStatistics = true)
- Full vertical height

### Right Side (200px width)

1. **Mini-Map** (180×180)
   - Top-right position
   - Shows overhead view of entire map
   - Blue dots (●) = unsaved hostages
   - White dot (◯) = player position
   - Updates every frame in real-time
   - Cyan border, black semi-transparent background
   - "MAP" title at top

## Layout Constants

```swift
let leftMarginWidth: CGFloat = 180
let rightMarginWidth: CGFloat = 200
```

## SceneView Constraints

```swift
sceneView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: leftMarginWidth)
sceneView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -rightMarginWidth)
```

## Benefits

✅ **Better use of screen space** - No empty areas in landscape mode
✅ **Clear visual hierarchy** - HUD on left, map on right, game in center  
✅ **Non-intrusive** - UI elements outside the 3D view don't block gameplay
✅ **Real-time feedback** - All stats update every frame
✅ **Scalable** - Easy to add more UI elements in margins

## Debug Mode

Debug HUD elements (Connection Status, Visibility, Distance) are hidden by default.
Enable via config server: `showDebugHUD: true`

## Notes

- All labels use **2-line layout** for compact vertical space
- **Autoresizing** enabled for text to fit
- **Rounded corners** (cornerRadius: 4-6) for modern look
- **Semi-transparent backgrounds** to maintain visibility over any background
- **Consistent spacing** (10pt between elements)
