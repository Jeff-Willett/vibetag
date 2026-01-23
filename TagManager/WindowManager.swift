//
//  WindowManager.swift
//  TagManager
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
            styleMask: [.titled, .closable, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )

        // Set minimum window size
        window.minSize = NSSize(width: 80, height: 60)

        // Configure window to float above all other windows, including fullscreen
        window.level = .floating  // Standard floating level allows tooltips to work
        window.collectionBehavior = [
            .canJoinAllSpaces,      // Appears on all virtual desktops
            .fullScreenAuxiliary,   // Shows above fullscreen windows (critical for IINA)
            .stationary,            // Stays in one place when switching spaces
            .transient              // Doesn't appear in window menu
        ]

        // Window appearance - hide titlebar completely
        window.title = "TagManager"
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
    // MARK: - Custom Tooltip

    private var tooltipWindow: NSWindow?

    func showTooltip(text: String, relativeTo view: NSView? = nil) {
        // Close existing tooltip if any
        hideTooltip()

        // Create content view for tooltip
        let tooltipView = NSTextField(labelWithString: text)
        tooltipView.textColor = .white
        tooltipView.font = .systemFont(ofSize: 11)
        tooltipView.backgroundColor = .clear
        tooltipView.isBezeled = false
        tooltipView.isEditable = false
        tooltipView.sizeToFit()

        let padding: CGFloat = 8
        let contentSize = NSSize(width: tooltipView.frame.width + 2 * padding, height: tooltipView.frame.height + 2 * padding)

        // Create tooltip window
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = NSColor.black.withAlphaComponent(0.9)
        window.hasShadow = true
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow))) // Higher than floating
        window.isReleasedWhenClosed = false // Critical: Prevent crash on release

        // Create a wrapper view for padding
        let wrapperView = NSView(frame: NSRect(origin: .zero, size: contentSize))
        wrapperView.wantsLayer = true
        wrapperView.layer?.cornerRadius = 6
        wrapperView.layer?.masksToBounds = true

        tooltipView.frame = NSRect(x: padding, y: padding, width: tooltipView.frame.width, height: tooltipView.frame.height)
        wrapperView.addSubview(tooltipView)
        window.contentView = wrapperView

        // Position window near cursor
        let mouseLocation = NSEvent.mouseLocation
        // Offset slightly so it doesn't overlap cursor immediately
        let newOrigin = NSPoint(x: mouseLocation.x + 10, y: mouseLocation.y - contentSize.height - 5)
        window.setFrameOrigin(newOrigin)

        window.orderFront(nil)
        self.tooltipWindow = window
    }

    func hideTooltip() {
        tooltipWindow?.close()
        tooltipWindow = nil
    }
}
