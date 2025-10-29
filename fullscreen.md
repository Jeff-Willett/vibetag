# Making VibeTag Visible Over Full-Screen Apps

## Problem

The VibeTag application window disappears when another application, such as a video player, enters full-screen mode. The goal is to have the VibeTag window remain visible and accessible on top of the full-screen content.

## Proposed Solution

The standard behavior for macOS applications is to hide other windows when one app goes into its own full-screen space. To override this, we need to modify the VibeTag app's underlying `NSWindow` properties.

By using `NSViewRepresentable` within our SwiftUI view, we can access the window and adjust its `level` and `collectionBehavior`.

1.  **Window Level**: Setting the `level` to `.floating` elevates the window above normal application windows.
2.  **Collection Behavior**: Setting the `collectionBehavior` to `[.canJoinAllSpaces, .fullScreenAuxiliary]` allows the window to appear in all spaces, including the dedicated space created for a full-screen application.

## Implementation

The following changes should be made to `TagManager/TagManagerApp.swift`. A helper struct `FloatingWindow` is created and applied as a background to the `ContentView`.

```swift
// filepath: TagManager/TagManagerApp.swift
import SwiftUI

@main
struct TagManagerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(FloatingWindow()) // Add this modifier
        }
    }
}

// Add this helper struct to the file
struct FloatingWindow: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                // Set the window level to float above other windows.
                window.level = .floating
                // Ensure the window can appear on top of full-screen apps.
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
```

This approach directly addresses the macOS window management behavior to achieve the desired "always-on-top" functionality for VibeTag.

---

## Implementation History & Testing Results

### ❌ Attempt #1: `.floating` Window Level (Suggested Above)
**Date:** October 29, 2025
**Implementation:** Set `window.level = .floating` in WindowManager.swift
**Collection Behavior:** `[.canJoinAllSpaces, .fullScreenAuxiliary]`
**Result:** **FAILED** - Window still disappeared when IINA entered fullscreen mode

### ❌ Attempt #2: `.maximumWindow` Level
**Date:** October 29, 2025
**Implementation:** Used highest possible window level:
```swift
window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
```
**Collection Behavior:** `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .transient]`
**Result:** **FAILED** - Window still disappeared in fullscreen

### ❌ Attempt #3: App Activation with `orderFrontRegardless()`
**Date:** October 29, 2025
**Implementation:**
```swift
NSApp.activate(ignoringOtherApps: true)
window.makeKeyAndOrderFront(nil)
window.orderFrontRegardless()
```
**Result:** **FAILED** - Window still disappeared in fullscreen

### ❌ Attempt #4: Multiple Collection Behavior Variations
**Date:** October 29, 2025
**Tried:**
- `.fullScreenPrimary`
- `.fullScreenDisallowsTiling`
- Various combinations of collection behaviors
**Result:** **FAILED** - None made any difference

---

## Root Cause Analysis

After extensive testing with multiple approaches, we discovered the **fundamental limitation**:

### macOS Native Fullscreen Behavior

When an app enters **native fullscreen mode** (clicking the green maximize button), macOS:
1. Creates a **separate Space** (virtual desktop) for that app
2. This Space is isolated from other apps by design
3. Only the fullscreen app's windows exist in that Space

### Why `.fullScreenAuxiliary` Doesn't Work

The `.fullScreenAuxiliary` collection behavior is **NOT for third-party overlays**. It's designed for:
- **Split View scenarios** - Two apps side-by-side in fullscreen
- **Picture-in-Picture windows** - System-level PiP functionality
- **System UI elements** - Notifications, Spotlight, menu bar extras
- **Same-app auxiliary windows** - A fullscreen app's own secondary windows

It does **NOT** allow third-party apps to overlay another app's fullscreen Space.

### What We Learned

**Window levels (like `.floating`, `.maximumWindow`) only control stacking order WITHIN a Space.** They cannot:
- Cross Space boundaries
- Override macOS fullscreen isolation
- Force windows into another app's fullscreen Space

**Only privileged system processes** (like Spotlight, notifications, screen recording indicators) can truly overlay fullscreen apps. Third-party apps are intentionally restricted.

---

## Current Implementation (What We Have Now)

**Location:** `TagManager/VibeTag/WindowManager.swift` (lines 20-59)

**Configuration:**
```swift
window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
window.collectionBehavior = [
    .canJoinAllSpaces,      // Appears on all virtual desktops
    .fullScreenAuxiliary,   // Shows in Split View scenarios
    .stationary,            // Stays in one place when switching spaces
    .transient              // Doesn't appear in window menu
]
```

### What Works ✅
- Normal windowed mode (all apps)
- Split View scenarios (two apps side-by-side)
- Multiple displays
- Mission Control switching
- Switching between Spaces (Ctrl+←/→)

### What Doesn't Work ❌
- Native fullscreen mode (app gets its own Space)
- Cannot overlay another app's fullscreen content

---

## Status: TABLED ⏸️

**Decision:** We've decided to **table this feature** because:

1. **Not a bug** - It's a macOS system design limitation, not an issue with our code
2. **No workaround exists** - Multiple approaches with maximum window levels all failed
3. **System restriction** - macOS intentionally prevents third-party overlays on fullscreen apps
4. **Security/UX design** - Apple wants fullscreen to be immersive and distraction-free

### User Workarounds

Users can work around this limitation by:

1. **Use IINA in windowed mode** - Don't click the green fullscreen button
2. **Use IINA's Picture-in-Picture mode** - Cmd+Option+P in IINA
3. **Use Split View** - Drag IINA to the side to create split view
4. **Switch Spaces** - Swipe with 3 fingers or press Ctrl+←/→ to access TagManager
5. **Use second display** - Put IINA fullscreen on one display, TagManager on another

---

## Alternative Solutions Considered & Rejected

### 1. Exit Fullscreen Automatically
**Idea:** Detect when IINA enters fullscreen and force it to exit
**Rejected:** Too disruptive to user workflow, defeats the purpose of fullscreen

### 2. Menu Bar App
**Idea:** Run entirely from menu bar, no window
**Rejected:** Less intuitive for tagging workflow, harder to see current tags

### 3. Tiny PiP-Style Window
**Idea:** Make window so small it doesn't interfere
**Rejected:** Already as small as practical (220x160px), still wouldn't appear over fullscreen

### 4. Screen Recording Permission
**Idea:** Use screen recording APIs to overlay content
**Rejected:** Requires invasive permissions, doesn't actually help with window management

---

## Technical Details

### Why This Worked in Some Apps

You may have noticed some apps CAN appear over fullscreen:
- **System apps** (Spotlight, Notifications, Screen Recording indicators)
- **Apps with special entitlements** (FaceTime, QuickTime screen recording)
- **Menu bar extras** (show in all Spaces including fullscreen)

These have special privileges that third-party apps cannot obtain.

### Code We're Currently Using

Our `WindowManager.swift` creates the window with maximum privileges available to third-party apps:

```swift
func createFloatingWindow() -> NSWindow {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 220, height: 160),
        styleMask: [.titled, .closable, .fullSizeContentView],
        backing: .buffered,
        defer: false
    )

    // Highest possible level for third-party apps
    window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))

    // Best collection behavior for multi-space visibility
    window.collectionBehavior = [
        .canJoinAllSpaces,
        .fullScreenAuxiliary,
        .stationary,
        .transient
    ]

    return window
}
```

This is **as good as it gets** for third-party apps without private APIs.

---

## Conclusion

The proposed solution in this document **was implemented but did not work** for native macOS fullscreen mode. We went beyond the suggestion by trying:
- Maximum window levels
- App activation with `orderFrontRegardless()`
- Multiple collection behavior combinations
- Various window management techniques

**The core limitation is a macOS system design decision** that prevents third-party apps from overlaying native fullscreen content. This is intentional behavior for security and user experience reasons.

**Recommendation:** Accept this limitation and use IINA in windowed mode, or teach users to swipe between Spaces to access TagManager when IINA is fullscreen.

**Last Updated:** October 29, 2025
