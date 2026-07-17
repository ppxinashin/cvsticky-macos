import AppKit
import Combine
import SwiftUI

private final class ClipboardPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSToolbarDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var clipboardPanel: NSPanel?
    private weak var mainWindow: NSWindow?
    private weak var configuredClipboardStore: ClipboardStore?
    private weak var clipboardSearchField: NSSearchField?
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
        configuredClipboardStore = clipboardStore

        let root = ClipboardOverlayView()
            .environmentObject(clipboardStore)
            .environmentObject(noteStore)
            .environmentObject(settings)
            .environmentObject(aiService)
        let controller = NSHostingController(rootView: root)
        let panel = ClipboardPanel(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 560),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = controller
        panel.title = "剪贴板历史"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.toolbarStyle = .unifiedCompact
        let toolbar = NSToolbar(identifier: "CVSticky.ClipboardHistoryToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        panel.toolbar = toolbar
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = true
        panel.backgroundColor = .windowBackgroundColor
        panel.hasShadow = true
        panel.hidesOnDeactivate = true
        panel.isMovableByWindowBackground = false
        panel.minSize = NSSize(width: 680, height: 440)
        clipboardPanel = panel

        settings.$hotKey.sink { [weak self] configuration in
            self?.hotKeyManager.register(configuration) { self?.showClipboard() }
        }.store(in: &cancellables)

        NotificationCenter.default.publisher(for: .cvstickyHideClipboard)
            .sink { [weak self] _ in self?.clipboardPanel?.orderOut(nil) }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .cvstickyShowSettings)
            .sink { [weak self] _ in self?.showSettings() }
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
        clipboardSearchField?.stringValue = configuredClipboardStore?.searchText ?? ""
    }

    @objc func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        guard let window = mainWindow ?? findMainWindow() else { return }
        installMainWindowBehavior(for: window)
        window.deminiaturize(nil)
        window.makeKeyAndOrderFront(nil)
    }

    @objc func newNote() {
        showMainWindow()
        NotificationCenter.default.post(name: .cvstickyNewNote, object: nil)
    }

    @objc func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: self) {
            return
        }
        _ = NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: self)
    }

    @objc func quit() { NSApp.terminate(nil) }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender === mainWindow || sender.identifier == .cvstickyMainWindow else {
            return true
        }
        sender.orderOut(nil)
        return false
    }

    @objc private func clipboardSearchChanged(_ sender: NSSearchField) {
        configuredClipboardStore?.searchText = sender.stringValue
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, .clipboardSearch]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, .clipboardSearch]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard itemIdentifier == .clipboardSearch else { return nil }
        let item = NSSearchToolbarItem(itemIdentifier: itemIdentifier)
        item.label = "搜索"
        item.paletteLabel = "搜索剪贴板历史"
        item.toolTip = "搜索剪贴板历史"
        item.searchField.placeholderString = "搜索剪贴板历史"
        item.searchField.sendsSearchStringImmediately = true
        item.searchField.target = self
        item.searchField.action = #selector(clipboardSearchChanged(_:))
        item.searchField.frame.size.width = 260
        clipboardSearchField = item.searchField
        return item
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "剪贴笺")
        let menu = NSMenu()
        menu.addItem(withTitle: "显示剪贴板历史", action: #selector(showClipboard), keyEquivalent: "")
        menu.addItem(withTitle: "打开剪贴笺", action: #selector(showMainWindow), keyEquivalent: "")
        menu.addItem(withTitle: "新建便签", action: #selector(newNote), keyEquivalent: "n")
        menu.addItem(.separator())
        let settingsMenuItem = menu.addItem(
            withTitle: "设置…",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsMenuItem.keyEquivalentModifierMask = [.command]
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出剪贴笺", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    private func styleMainWindow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self, let window = findMainWindow() else { return }
            installMainWindowBehavior(for: window)
        }
    }

    private func findMainWindow() -> NSWindow? {
        if let mainWindow { return mainWindow }
        return NSApp.windows.first { $0.identifier == .cvstickyMainWindow }
            ?? NSApp.windows.first { !$0.isKind(of: NSPanel.self) && $0.title == "剪贴笺" }
    }

    private func installMainWindowBehavior(for window: NSWindow) {
        mainWindow = window
        window.identifier = .cvstickyMainWindow
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = false
        if #available(macOS 26.0, *) {
            window.toolbarStyle = .unified
        }
    }
}

private extension NSToolbarItem.Identifier {
    static let clipboardSearch = NSToolbarItem.Identifier("CVSticky.ClipboardSearch")
}

private extension NSUserInterfaceItemIdentifier {
    static let cvstickyMainWindow = NSUserInterfaceItemIdentifier("CVSticky.MainWindow")
}
