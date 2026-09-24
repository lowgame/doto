import AppKit
import SwiftUI

final class DotoPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if (event.charactersIgnoringModifiers?.lowercased() == "s" || event.keyCode == 1) && event.modifierFlags.contains(.command) {
            NotificationCenter.default.post(name: .dotoTriggerSave, object: nil)
            return
        }
        super.keyDown(with: event)
    }
}

@MainActor
public final class DotoPanelController: NSObject, NSWindowDelegate {
    public static let shared = DotoPanelController()

    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var eventMonitor: Any?

    private let taskManager = TaskManager()
    private let noteManager = NoteManager()
    private var isDetached: Bool = false

    private override init() {
        super.init()
    }

    public func setup() {
        setupMainMenu()
        setupStatusItem()
        setupPanel()
        NotificationManager.shared.requestAuthorization()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.statusItemClicked()
        }
    }

    // MARK: - Main Menu (Enables standard Cmd+A, Cmd+C, Cmd+V, Cmd+Z shortcuts)

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "doto")
        let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLoginAction), keyEquivalent: "")
        launchAtLoginItem.target = self
        launchAtLoginItem.state = LaunchAtLoginManager.shared.isEnabled ? .on : .off
        appMenu.addItem(launchAtLoginItem)
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit doto", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // File Menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        let saveItem = NSMenuItem(title: "Save to iCloud", action: #selector(saveToiCloudAction), keyEquivalent: "s")
        saveItem.target = self
        fileMenu.addItem(saveItem)
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // Edit Menu
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")

        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redoItem = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(redoItem)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        NSApp.mainMenu = mainMenu
    }

    @objc private func toggleLaunchAtLoginAction() {
        LaunchAtLoginManager.shared.toggle()
        setupMainMenu()
    }

    @objc private func saveToiCloudAction() {
        NotificationCenter.default.post(name: .dotoTriggerSave, object: nil)
    }

    // MARK: - Status Item Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }

        updateStatusItemDot()

        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    public func updateStatusItemDot() {
        guard let button = statusItem?.button else { return }

        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let dotRect = NSRect(x: 5, y: 5, width: 8, height: 8)
            let path = NSBezierPath(ovalIn: dotRect)

            // Minimalist monochrome dot (uses template color for dark/light mode adaptation)
            NSColor.labelColor.setFill()
            path.fill()
            return true
        }
        image.isTemplate = true
        button.image = image
    }

    // MARK: - Panel Setup

    private func setupPanel() {
        let popoverContent = DotoPopoverView(
            taskManager: taskManager,
            noteManager: noteManager,
            isDetached: isDetached,
            onToggleDetach: { [weak self] in
                self?.toggleDetachMode()
            }
        )

        let hostingView = NSHostingView(rootView: popoverContent)

        let panel = DotoPanel(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 460),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.contentView = hostingView
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.delegate = self

        self.panel = panel
    }

    private func updatePanelContent() {
        let popoverContent = DotoPopoverView(
            taskManager: taskManager,
            noteManager: noteManager,
            isDetached: isDetached,
            onToggleDetach: { [weak self] in
                self?.toggleDetachMode()
            }
        )
        panel?.contentView = NSHostingView(rootView: popoverContent)
    }

    // MARK: - Actions

    @objc private func statusItemClicked() {
        if isDetached {
            // If already detached as floating widget, bring to front or toggle visibility
            if let panel = panel {
                if panel.isVisible {
                    panel.orderOut(nil)
                } else {
                    panel.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        } else {
            toggleDockedPanel()
        }
    }

    private func toggleDockedPanel() {
        guard let panel = panel, let button = statusItem?.button else { return }

        if panel.isVisible {
            closeDockedPanel()
        } else {
            showDockedPanel(relativeTo: button)
        }
    }

    private func showDockedPanel(relativeTo button: NSStatusBarButton) {
        guard let panel = panel else { return }

        // Position panel directly beneath the status item dot
        let buttonFrame = button.window?.convertToScreen(button.frame) ?? .zero
        let panelWidth = panel.frame.width
        let x = buttonFrame.midX - (panelWidth / 2)
        let y = buttonFrame.minY - panel.frame.height - 4

        panel.setFrameOrigin(NSPoint(x: max(10, x), y: y))
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Close on outside click when docked
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, !self.isDetached else { return }
            if let panel = self.panel, panel.isVisible {
                let mouseLocation = NSEvent.mouseLocation
                if !panel.frame.contains(mouseLocation) {
                    self.closeDockedPanel()
                }
            }
        }
    }

    private func closeDockedPanel() {
        panel?.orderOut(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    public func toggleDetachMode() {
        isDetached.toggle()
        if isDetached {
            // Detached: remove outside click monitor so it stays on desktop
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
            panel?.level = .floating
        } else {
            // Re-docking: move back to status button if visible
            if let button = statusItem?.button, panel?.isVisible == true {
                let buttonFrame = button.window?.convertToScreen(button.frame) ?? .zero
                let panelWidth = panel?.frame.width ?? 350
                let x = buttonFrame.midX - (panelWidth / 2)
                let y = buttonFrame.minY - (panel?.frame.height ?? 460) - 4
                panel?.setFrameOrigin(NSPoint(x: max(10, x), y: y))
            }
        }
        updatePanelContent()
    }
}

extension Notification.Name {
    public static let dotoTriggerSave = Notification.Name("dotoTriggerSave")
}
