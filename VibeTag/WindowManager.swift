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
        // Create window with specific size (320x450pt as per requirements)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 450),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Configure window to float above all other windows
        window.level = .popUpMenu  // Stays above most windows
        window.collectionBehavior = [
            .canJoinAllSpaces,      // Appears on all virtual desktops
            .fullScreenAuxiliary,   // Shows above fullscreen windows (critical for IINA)
            .transient              // Doesn't appear in window menu
        ]

        // Window appearance
        window.title = "VibeTag"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor.windowBackgroundColor

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
            return
        }

        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.makeKeyAndOrderFront(nil)
        }
    }

    func showWindow() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
        } else {
            _ = createFloatingWindow()
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
