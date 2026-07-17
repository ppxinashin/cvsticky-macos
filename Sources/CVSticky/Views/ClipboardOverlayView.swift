import AppKit
import SwiftUI

struct ClipboardOverlayView: View {
    @EnvironmentObject private var clipboardStore: ClipboardStore
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var settings: SettingsStore

    @State private var selectedIndex = 0
    @State private var feedback = ""
    @State private var aiEntry: ClipboardEntry?
    @State private var aiActions: [AIPinAction] = []

    private var selected: ClipboardEntry? {
        let items = clipboardStore.filteredEntries
        guard items.indices.contains(selectedIndex) else { return items.first }
        return items[selectedIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "clipboard.fill").foregroundColor(.accentColor)
                SearchField(text: $clipboardStore.searchText, placeholder: "搜索剪贴板历史")
                Button(action: { settings.appearance = settings.appearance == .dark ? .light : .dark }) {
                    Image(systemName: settings.appearance == .dark ? "sun.max" : "moon")
                }.buttonStyle(.plain)
                Button(action: hide) { Image(systemName: "xmark") }.buttonStyle(.plain)
            }
            .padding(14)

            Divider()
            HSplitView {
                entryList.frame(minWidth: 300, idealWidth: 360)
                preview.frame(minWidth: 320)
            }
            Divider()
            HStack {
                Text(feedback.isEmpty ? "↑↓ 选择 · Enter 复制 · Esc 关闭" : feedback)
                    .font(.caption).foregroundColor(.secondary)
                Spacer()
                if let selected {
                    Button(action: { pin(selected) }) {
                        Label(selected.isPinned ? "已固定" : "原文固定", systemImage: selected.isPinned ? "pin.fill" : "pin")
                    }.disabled(selected.isPinned)
                    Button(action: { generateAI(for: selected) }) {
                        Label("AI 整理", systemImage: "sparkles")
                    }.disabled(aiService.isLoading || selected.type == .image || selected.type == .files)
                    Button(action: { clipboardStore.delete(selected) }) {
                        Image(systemName: "trash")
                    }.help("删除")
                }
            }
            .padding(12)
        }
        .frame(width: 760, height: 540)
        .background(VisualEffectView(material: .hudWindow))
        .adaptiveGlass(radius: 24, material: .hudWindow)
        .accentColor(Color(nsColor: settings.accentColor))
        .onMoveCommand(perform: moveSelection)
        .onExitCommand(perform: hide)
        .background(
            Button(action: copySelected) { EmptyView() }
                .keyboardShortcut(.defaultAction)
                .hidden()
        )
        .sheet(item: $aiEntry) { entry in aiSheet(entry) }
        .onChange(of: clipboardStore.searchText) { _ in selectedIndex = 0 }
    }

    private var entryList: some View {
        List(selection: Binding(
            get: { selected?.id },
            set: { id in selectedIndex = clipboardStore.filteredEntries.firstIndex(where: { $0.id == id }) ?? 0 }
        )) {
            ForEach(Array(clipboardStore.filteredEntries.enumerated()), id: \.element.id) { index, entry in
                HStack(spacing: 10) {
                    Image(systemName: entry.type.symbol).frame(width: 22).foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.displayText.replacingOccurrences(of: "\n", with: " ")).lineLimit(2)
                        HStack {
                            Text(entry.type.title)
                            Text("•")
                            Text(entry.sourceApp)
                            Spacer()
                            Text(entry.createdAt, style: .time)
                        }.font(.caption).foregroundColor(.secondary)
                    }
                    if entry.isPinned { Image(systemName: "pin.fill").font(.caption).foregroundColor(.accentColor) }
                }
                .padding(.vertical, 5)
                .tag(entry.id)
                .onTapGesture(count: 2) { clipboardStore.copy(entry); copied() }
                .contextMenu {
                    Button("复制") { clipboardStore.copy(entry); copied() }
                    Button("固定为便签") { pin(entry) }.disabled(entry.isPinned)
                    Button("AI 整理") { generateAI(for: entry) }.disabled(entry.type == .image || entry.type == .files)
                    Divider()
                    Button("删除") { clipboardStore.delete(entry) }
                }
            }
        }
        .listStyle(.inset)
    }

    @ViewBuilder
    private var preview: some View {
        if let entry = selected {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label(entry.type.title, systemImage: entry.type.symbol).font(.headline)
                        Spacer()
                        Text(entry.createdAt, style: .date).foregroundColor(.secondary)
                    }
                    Divider()
                    if entry.type == .image, let path = entry.imagePath, let image = NSImage(contentsOfFile: path) {
                        Image(nsImage: image).resizable().scaledToFit().cornerRadius(12)
                    } else if entry.type == .files {
                        ForEach(entry.filePaths, id: \.self) { path in
                            HStack {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable().frame(width: 32, height: 32)
                                VStack(alignment: .leading) {
                                    Text(URL(fileURLWithPath: path).lastPathComponent)
                                    Text(path).font(.caption).foregroundColor(.secondary).lineLimit(1)
                                }
                            }
                        }
                    } else {
                        Text(entry.text ?? "").textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.padding(18)
            }
        } else {
            EmptyStateView(title: "暂无剪贴记录", symbol: "clipboard", detail: "复制文本、图片或文件后会自动出现。")
        }
    }

    private func aiSheet(_ entry: ClipboardEntry) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("AI 整理方案", systemImage: "sparkles").font(.title3.bold())
                Spacer()
                Button("关闭") { aiEntry = nil }
            }
            if aiService.isLoading {
                VStack(spacing: 14) {
                    ProgressView("正在生成整理方案…")
                    if !aiService.streamedText.isEmpty {
                        ScrollView { Text(aiService.streamedText).font(.caption).textSelection(.enabled) }
                            .frame(maxHeight: 260)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 12)], spacing: 12) {
                        ForEach(aiActions) { action in
                            Button(action: { applyAI(action, to: entry) }) {
                                VStack(alignment: .leading, spacing: 7) {
                                    Text(action.label).font(.headline)
                                    Text(action.title).foregroundColor(.primary).lineLimit(1)
                                    Text(action.contentMarkdown).font(.caption).foregroundColor(.secondary).lineLimit(4)
                                }
                                .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                                .padding(12)
                                .adaptiveGlass(radius: 14, material: .popover)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 620, height: 430)
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        switch direction {
        case .down: selectedIndex = min(selectedIndex + 1, max(clipboardStore.filteredEntries.count - 1, 0))
        case .up: selectedIndex = max(selectedIndex - 1, 0)
        default: break
        }
    }

    private func copySelected() { if let selected { clipboardStore.copy(selected); copied() } }
    private func copied() { feedback = "已复制到剪贴板"; DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: hide) }
    private func hide() { NotificationCenter.default.post(name: .cvstickyHideClipboard, object: nil) }

    private func pin(_ entry: ClipboardEntry) {
        if noteStore.create(from: entry) != nil {
            clipboardStore.markPinned(entry.id); feedback = "已按原文转为便签"
        }
    }

    private func generateAI(for entry: ClipboardEntry) {
        aiEntry = entry
        aiActions = []
        Task { aiActions = await aiService.generateActions(for: entry.text ?? entry.displayText) }
    }

    private func applyAI(_ action: AIPinAction, to entry: ClipboardEntry) {
        Task {
            let source = entry.text ?? entry.displayText
            let content = action.id == "save" || action.contentMarkdown != source
                ? action.contentMarkdown
                : await aiService.transform(source, instruction: action.prompt)
            if noteStore.create(from: entry, title: action.title, markdown: content) != nil {
                clipboardStore.markPinned(entry.id); aiEntry = nil; feedback = "AI 便签已创建"
            }
        }
    }
}

extension Notification.Name {
    static let cvstickyHideClipboard = Notification.Name("CVSticky.hideClipboard")
}
