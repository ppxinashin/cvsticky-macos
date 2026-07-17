import SwiftUI

@main
struct CVStickyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var clipboardStore: ClipboardStore
    @StateObject private var noteStore: NoteStore
    @StateObject private var settings: SettingsStore
    @StateObject private var aiService: AIService

    init() {
        let settings = SettingsStore()
        _clipboardStore = StateObject(wrappedValue: ClipboardStore())
        _noteStore = StateObject(wrappedValue: NoteStore())
        _settings = StateObject(wrappedValue: settings)
        _aiService = StateObject(wrappedValue: AIService(settings: settings))
    }

    var body: some Scene {
        WindowGroup("剪贴笺") {
            MainView()
                .environmentObject(clipboardStore)
                .environmentObject(noteStore)
                .environmentObject(settings)
                .environmentObject(aiService)
                .onAppear {
                    clipboardStore.start()
                    appDelegate.configure(
                        clipboardStore: clipboardStore,
                        noteStore: noteStore,
                        settings: settings,
                        aiService: aiService
                    )
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建便签") { NotificationCenter.default.post(name: .cvstickyNewNote, object: nil) }
                    .keyboardShortcut("n", modifiers: .command)
                Button("显示剪贴板历史") { appDelegate.showClipboard() }
                    .keyboardShortcut("v", modifiers: .option)
            }
        }
    }
}
