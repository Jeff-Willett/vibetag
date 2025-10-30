//
//  ShortcutManager.swift
//  TagManager
//
//  Manages global keyboard shortcuts for toggling the window
//

import AppKit
import Carbon

class ShortcutManager {
    static let shared = ShortcutManager()

    private var eventHandler: EventHandlerRef?
    private var eventHotKeyRef: EventHotKeyRef?
    private var onShortcutPressed: (() -> Void)?

    private init() {}

    /// Register global shortcut (Cmd+Shift+T by default)
    func registerShortcut(onPressed: @escaping () -> Void) {
        self.onShortcutPressed = onPressed

        // Define the hotkey: Cmd+Shift+T
        let keyCode: UInt32 = 17 // T key
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)

        // Create event type
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)

        // Install event handler
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, theEvent, userData) -> OSStatus in
                ShortcutManager.shared.handleHotKeyEvent(nextHandler, theEvent, userData)
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )

        // Register the hotkey
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x56544147) // 'VTAG'
        hotKeyID.id = 1

        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &eventHotKeyRef
        )

        print("✓ Global shortcut registered: Cmd+Shift+T")
    }

    /// Unregister the shortcut
    func unregisterShortcut() {
        if let eventHotKeyRef = eventHotKeyRef {
            UnregisterEventHotKey(eventHotKeyRef)
            self.eventHotKeyRef = nil
        }

        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    /// Handle the hotkey event
    private func handleHotKeyEvent(
        _ nextHandler: EventHandlerCallRef?,
        _ theEvent: EventRef?,
        _ userData: UnsafeMutableRawPointer?
    ) -> OSStatus {
        // Call the callback on main thread
        DispatchQueue.main.async {
            self.onShortcutPressed?()
        }

        return noErr
    }

    deinit {
        unregisterShortcut()
    }
}
