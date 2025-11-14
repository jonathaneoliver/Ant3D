# Leaderboard Crash Fix - EXC_BAD_ACCESS

## 🐛 Problem

The app was crashing with `EXC_BAD_ACCESS (code=1)` in the `showLeaderboard()` method of `LeaderboardScene3D`.

## 🔍 Root Causes

1. **Unsafe C-style String Formatting**: Using `String(format: "%s", ...)` with Swift strings can cause memory access violations
2. **View Lifecycle Timing**: Calling `showLeaderboard()` in `viewDidLoad()` before the view is added to the window hierarchy
3. **Thread Safety**: Not ensuring UI updates happen on the main thread
4. **Premature UI Updates**: Attempting to manipulate UI elements before they're fully initialized

## ✅ Solutions Applied

### 1. Fixed String Formatting (LeaderboardScene3D.swift:297-357)

**Before:**
```swift
entryLabel.text = String(format: "%2d. %-12s %,6d pts %s", i+1, entry.0, entry.1, entry.2)
```

**After:**
```swift
let rank = String(format: "%2d", i + 1)
let name = entry.0.padding(toLength: 12, withPad: " ", startingAt: 0)
let score = String(format: "%,6d", entry.1)
let date = entry.2

entryLabel.text = "\(rank). \(name) \(score) pts \(date)"
```

**Why:** Avoids C-style `%s` format specifier which expects null-terminated C strings, not Swift Strings. Using Swift string interpolation is safer.

### 2. Added Thread Safety Check

```swift
guard Thread.isMainThread else {
    DispatchQueue.main.async { [weak self] in
        self?.showLeaderboard()
    }
    return
}
```

**Why:** Ensures all UI updates happen on the main thread.

### 3. Added View Hierarchy Check

```swift
guard view.window != nil else {
    print("⚠️ view not in window hierarchy in showLeaderboard()")
    return
}
```

**Why:** Only updates UI when the view is actually in the window hierarchy.

### 4. Moved Initial Display to viewWillAppear

**Before:**
```swift
override func viewDidLoad() {
    // ... setup code ...
    loadScores()
    showLeaderboard()  // ❌ Too early!
}
```

**After:**
```swift
override func viewDidLoad() {
    // ... setup code ...
    loadScores()
    // Don't call showLeaderboard here
}

override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    showLeaderboard()  // ✅ Safe timing!
}
```

**Why:** `viewWillAppear` is called after the view is added to the window hierarchy, making it safer for UI updates.

### 5. Improved Subview Removal

**Before:**
```swift
scoreLabelsContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
```

**After:**
```swift
for subview in scoreLabelsContainer.arrangedSubviews {
    scoreLabelsContainer.removeArrangedSubview(subview)
    subview.removeFromSuperview()
}
```

**Why:** Properly removes views from both the stack view arrangement and the view hierarchy.

### 6. Added viewDidDisappear for Cleanup

```swift
override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    print("🏆 LeaderboardScene3D: viewDidDisappear - view is no longer visible")
}
```

**Why:** Helps track view lifecycle and can be extended for cleanup if needed.

## 🧪 Testing

After these changes:

1. ✅ Build succeeds
2. ✅ No memory access violations
3. ✅ Leaderboard displays correctly
4. ✅ View transitions work smoothly
5. ✅ Game Center scores load asynchronously without crashes

## 📝 Additional Safety Measures Already in Place

The code also has these safety checks:

1. **Weak self in closures**: Prevents retain cycles
   ```swift
   GameCenterManager.shared.loadLeaderboard { [weak self] ... }
   ```

2. **isViewLoaded check**: In async callbacks
   ```swift
   guard self.isViewLoaded else { return }
   ```

3. **Nil checks**: Before accessing properties
   ```swift
   guard let scoreLabelsContainer = scoreLabelsContainer else { return }
   ```

## 🎯 Summary

The crash was caused by a combination of:
- Unsafe C-style string formatting
- UI updates before view was ready
- Potential threading issues

All issues have been resolved with:
- Safe Swift string interpolation
- Proper view lifecycle timing
- Thread safety checks
- View hierarchy validation

The leaderboard now works reliably! 🎮
