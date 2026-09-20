import AppKit
import Carbon.HIToolbox
import SwiftUI

/// The search window. It is a panel, so the hot key can show it over another app
/// and that app stays active. A paste then goes to that app.
final class SearchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let model = SearchModel()
    private var panel: SearchPanel!
    /// True after the hot key showed the panel. A click then copies, hides the panel, and pastes.
    private var isSummoned = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = Self.mainMenu()

        panel = SearchPanel(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.appearance = NSAppearance(named: .aqua)
        panel.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        panel.minSize = NSSize(width: 700, height: 520)
        panel.contentView = NSHostingView(rootView: ContentView(model: model))
        panel.delegate = self
        panel.center()
        panel.setFrameAutosaveName("SearchPanel")

        model.onCopied = { [weak self] in self?.pasteIfSummoned() }
        model.onEscape = { [weak self] in
            if self?.isSummoned == true { self?.hide() }
        }
        HotKey.register(keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey | optionKey)) { [weak self] in
            self?.toggle()
        }
        show()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        show()
        return true
    }

    private func show() {
        isSummoned = false
        panel.level = .normal
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        model.focusRequests += 1
    }

    private func toggle() {
        if panel.isVisible, panel.isKeyWindow {
            hide()
        } else {
            isSummoned = true
            panel.level = .floating
            panel.makeKeyAndOrderFront(nil)
            model.focusRequests += 1
        }
    }

    private func hide() {
        isSummoned = false
        panel.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        guard isSummoned else { return }
        // The key popover is a child window. Every other loss of focus dismisses the panel.
        DispatchQueue.main.async { [self] in
            if let key = NSApp.keyWindow, key === panel || key.parent === panel { return }
            if isSummoned { hide() }
        }
    }

    private func pasteIfSummoned() {
        guard isSummoned else { return }
        hide()
        // The paste needs the Accessibility permission. The app asks one time only.
        // Without the permission, the name is only copied.
        guard AXIsProcessTrusted() else {
            if !UserDefaults.standard.bool(forKey: "didAskForAccessibility") {
                UserDefaults.standard.set(true, forKey: "didAskForAccessibility")
                _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
            }
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let source = CGEventSource(stateID: .combinedSessionState)
            for keyDown in [true, false] {
                let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: keyDown)
                event?.flags = .maskCommand
                event?.post(tap: .cghidEventTap)
            }
        }
    }

    /// A text field needs the Edit menu for Command-V, Command-A, and the other shortcuts.
    private static func mainMenu() -> NSMenu {
        let main = NSMenu()
        let app = NSMenu()
        app.addItem(withTitle: "Hide FindSFSymbols", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(withTitle: "Quit FindSFSymbols", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let window = NSMenu(title: "Window")
        window.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        window.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        for menu in [app, edit, window] {
            let item = NSMenuItem()
            item.submenu = menu
            main.addItem(item)
        }
        return main
    }
}

/// One system-wide hot key. Carbon hot keys need no permission.
@MainActor
enum HotKey {
    private static var action: () -> Void = {}

    static func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        Self.action = action
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            MainActor.assumeIsolated { HotKey.action() }
            return noErr
        }, 1, &pressed, nil, nil)
        var reference: EventHotKeyRef?
        RegisterEventHotKey(
            keyCode, modifiers, EventHotKeyID(signature: 0x4653_5946, id: 1), GetApplicationEventTarget(), 0, &reference)
    }
}
