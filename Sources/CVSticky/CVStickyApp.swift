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
            CommandGroup(replacing: .help) {
                Button("剪贴笺帮助") { appDelegate.showHelp() }
                    .keyboardShortcut("?", modifiers: .command)
            }
            CommandGroup(replacing: .newItem) {
                Button("新建便签") { NotificationCenter.default.post(name: .cvstickyNewNote, object: nil) }
                    .keyboardShortcut("n", modifiers: .command)
                Button("显示剪贴板历史") { appDelegate.showClipboard() }
                    .keyboardShortcut("v", modifiers: .option)
            }
            CommandGroup(after: .sidebar) {
                Button("显示或隐藏边栏") {
                    NotificationCenter.default.post(name: .cvstickyToggleSidebar, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.option, .command])
            }
            CommandGroup(after: .pasteboard) {
                Divider()
                Menu("便签格式") {
                    ForEach(1...6, id: \.self) { level in
                        Button("\(level) 级标题") { sendEditorCommand("heading\(level)") }
                    }
                    Divider()
                    Button("粗体") { sendEditorCommand("bold") }
                        .keyboardShortcut("b", modifiers: .command)
                    Button("斜体") { sendEditorCommand("italic") }
                        .keyboardShortcut("i", modifiers: .command)
                    Button("下划线") { sendEditorCommand("underline") }
                        .keyboardShortcut("u", modifiers: .command)
                    Button("删除线") { sendEditorCommand("strike") }
                    Button("行内代码") { sendEditorCommand("code") }
                }
                Menu("便签列表") {
                    Button("无序列表") { sendEditorCommand("bulletList") }
                    Button("有序列表") { sendEditorCommand("orderedList") }
                    Button("任务列表") { sendEditorCommand("taskList") }
                    Button("引用") { sendEditorCommand("quote") }
                }
                Menu("便签插入") {
                    Button("代码块") { sendEditorCommand("codeBlock") }
                    Button("Mermaid 流程图") { sendEditorCommand("mermaid") }
                    Button("数学公式") { sendEditorCommand("math") }
                    Button("表格（3 × 3）") { sendEditorCommand("table", row: 3, column: 3) }
                    Divider()
                    Button("链接") { sendEditorCommand("link") }
                    Button("图片…") { sendEditorCommand("image") }
                }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(noteStore)
                .environmentObject(settings)
                .environmentObject(aiService)
        }
    }

    private func sendEditorCommand(_ command: String, row: Int? = nil, column: Int? = nil) {
        NotificationCenter.default.post(
            name: .markdownEditorCommand,
            object: MarkdownEditorCommandRequest(
                noteID: nil,
                command: command,
                row: row,
                column: column
            )
        )
    }
}
