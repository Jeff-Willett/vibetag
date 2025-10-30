//
//  VibeTagApp.swift
//  VibeTag
//
//  Created by Jeff Willett on 10/28/25.
//

import SwiftUI
import AppKit

// Notification for triggering IINA file detection
extension Notification.Name {
    static let detectIINAFile = Notification.Name("detectIINAFile")
}

@main
struct VibeTagApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // We use an empty WindowGroup because the actual window
        // is managed by WindowManager for proper floating behavior
        WindowGroup {
            EmptyView()
        }
        .commands {
            // Remove default File menu commands
            CommandGroup(replacing: .newItem) { }
        }
    }
}

// AppDelegate to handle app lifecycle and window creation
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var floatingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide the default empty window
        if let window = NSApplication.shared.windows.first {
            window.close()
        }

        // Create the floating window with our content
        let floatingWindow = WindowManager.shared.createFloatingWindow()
        let contentView = ContentView()
        floatingWindow.contentView = NSHostingView(rootView: contentView)
        self.floatingWindow = floatingWindow

        // Set up menu bar icon
        setupMenuBarIcon()

        // Make the app activate without needing to be in the Dock
        NSApp.setActivationPolicy(.accessory)

        // Register global keyboard shortcut (Cmd+Shift+T)
        ShortcutManager.shared.registerShortcut { [weak self] in
            self?.handleShortcut()
        }
    }

    func handleShortcut() {
        // Toggle window and auto-detect IINA file when shown
        WindowManager.shared.toggleWindow()

        // Trigger file detection if window is now visible
        if let window = floatingWindow, window.isVisible {
            // Post notification to trigger file detection in ContentView
            NotificationCenter.default.post(name: .detectIINAFile, object: nil)
        }
    }

    func setupMenuBarIcon() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "tag.fill", accessibilityDescription: "VibeTag")
            button.action = #selector(toggleWindow)
            button.target = self
        }

        // Create menu for status item
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Window", action: #selector(toggleWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit VibeTag", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc func toggleWindow() {
        WindowManager.shared.toggleWindow()
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Show window when app icon is clicked
        if !flag {
            WindowManager.shared.showWindow()
        }
        return true
    }
}