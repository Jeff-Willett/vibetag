//
//  WindowManager.swift
//  VibeTag
//
//  Manages the floating window that stays on top of all other windows
//

import AppKit
import SwiftUI

class WindowManager: NSObject, NSWindowDelegate {
    static let shared = WindowManager()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    func createFloatingWindow() -> NSWindow {
        // Create window with minimal size (220x160pt for ultra-compact UI)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 160),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Configure window to float above all other windows, including fullscreen
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))  // Highest possible level
        window.collectionBehavior = [
            .canJoinAllSpaces,      // Appears on all virtual desktops
            .fullScreenAuxiliary,   // Shows above fullscreen windows (critical for IINA)
            .stationary,            // Stays in one place when switching spaces
            .transient              // Doesn't appear in window menu
        ]

        // Window appearance - hide titlebar completely
        window.title = "VibeTag"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor.windowBackgroundColor
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        // Center window on screen
        window.center()

        // Set delegate to handle window events
        window.delegate = self

        // Make window appear
        window.makeKeyAndOrderFront(nil)

        self.window = window
        return window
    }

    func toggleWindow() {
        guard let window = window else {
            _ = createFloatingWindow()
            // Activate app to ensure window appears in fullscreen
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        if window.isVisible {
            window.orderOut(nil)
        } else {
            // Ensure window appears above fullscreen by activating the app
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()  // Force window to front
        }
    }

    func showWindow() {
        if let window = window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        } else {
            _ = createFloatingWindow()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func hideWindow() {
        window?.orderOut(nil)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // Clean up when window closes
        window = nil
    }

    // Handle ESC key to dismiss without stealing focus
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Instead of closing, just hide the window
        hideWindow()
        return false
    }
}
