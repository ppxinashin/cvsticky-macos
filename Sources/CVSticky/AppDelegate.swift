import AppKit
import Combine
import SwiftUI

private final class ClipboardPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var clipboardPanel: NSPanel?
    private let hotKeyManager = GlobalHotKeyManager()
    private var cancellables = Set<AnyCancellable>()
    private var configured = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        setupStatusItem()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func configure(
        clipboardStore: ClipboardStore,
        noteStore: NoteStore,
        settings: SettingsStore,
        aiService: AIService
    ) {
        guard !configured else { return }
        configured = true

        let root = ClipboardOverlayView()
            .environmentObject(clipboardStore)
            .environmentObject(noteStore)
            .environmentObject(settings)
            .environmentObject(aiService)
        let controller = NSHostingController(rootView: root)
        let panel = ClipboardPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 540),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = controller
        panel.title = "剪贴板历史"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        clipboardPanel = panel

        settings.$hotKey.sink { [weak self] configuration in
            self?.hotKeyManager.register(configuration) { self?.showClipboard() }
        }.store(in: &cancellables)

        NotificationCenter.default.publisher(for: .cvstickyHideClipboard)
            .sink { [weak self] _ in self?.clipboardPanel?.orderOut(nil) }
            .store(in: &cancellables)

        styleMainWindow()
    }

    @objc func showClipboard() {
        guard let panel = clipboardPanel else { return }
        let mouse = NSEvent.mouseLocation
        let target = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        if let frame = target?.visibleFrame {
            panel.setFrameOrigin(NSPoint(
                x: frame.midX - panel.frame.width / 2,
                y: frame.midY - panel.frame.height / 2
            ))
        } else { panel.center() }
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    @objc func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first(where: { !$0.isKind(of: NSPanel.self) })?.makeKeyAndOrderFront(nil)
    }

    @objc func newNote() {
        showMainWindow()
        NotificationCenter.default.post(name: .cvstickyNewNote, object: nil)
    }

    @objc func quit() { NSApp.terminate(nil) }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "剪贴笺")
        let menu = NSMenu()
        menu.addItem(withTitle: "显示剪贴板历史", action: #selector(showClipboard), keyEquivalent: "")
        menu.addItem(withTitle: "打开剪贴笺", action: #selector(showMainWindow), keyEquivalent: "")
        menu.addItem(withTitle: "新建便签", action: #selector(newNote), keyEquivalent: "n")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出剪贴笺", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    private func styleMainWindow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard let window = NSApp.windows.first(where: { !$0.isKind(of: NSPanel.self) }) else { return }
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = false
            if #available(macOS 26.0, *) {
                window.toolbarStyle = .unified
            }
        }
    }
}
