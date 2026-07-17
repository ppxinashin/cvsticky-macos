import AppKit
import SwiftUI

struct ClipboardOverlayView: View {
    @EnvironmentObject private var clipboardStore: ClipboardStore
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var settings: SettingsStore

    @State private var selectedID: UUID?
    @State private var feedback = ""
    @State private var aiEntry: ClipboardEntry?
    @State private var aiActions: [AIPinAction] = []
    @State private var aiKind: AITransformKind = .smart
    @State private var aiRequirement = ""
    @State private var aiTargetLanguage = "简体中文"

    private var selected: ClipboardEntry? {
        let items = clipboardStore.filteredEntries
        guard let selectedID else { return items.first }
        return items.first(where: { $0.id == selectedID }) ?? items.first
    }

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                entryList.frame(minWidth: 300, idealWidth: 360)
                preview.frame(minWidth: 320)
            }
            Divider()
            HStack(spacing: 10) {
                Text(feedback.isEmpty ? "↑↓ 选择   Return 复制   Esc 关闭" : feedback)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let selected {
                    Button(action: { pin(selected) }) {
                        Label(selected.isPinned ? "已存为便签" : "存为便签", systemImage: selected.isPinned ? "pin.fill" : "pin")
                    }
                    .disabled(selected.isPinned)
                    Button(action: { generateAI(for: selected) }) {
                        Label("AI 整理", systemImage: "sparkles")
                    }
                    .disabled(aiService.isLoading || selected.type == .image || selected.type == .files)
                    Menu {
                        Button("删除记录", role: .destructive) {
                            clipboardStore.delete(selected)
                        }
                    } label: {
                        Label("更多", systemImage: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
            .controlSize(.small)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .frame(minWidth: 680, idealWidth: 820, minHeight: 440, idealHeight: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        .accentColor(Color(nsColor: settings.accentColor))
        .onMoveCommand(perform: moveSelection)
        .onExitCommand(perform: hide)
        .background(
            Button(action: copySelected) { EmptyView() }
                .keyboardShortcut(.defaultAction)
                .hidden()
        )
        .sheet(item: $aiEntry) { entry in aiSheet(entry) }
        .onAppear(perform: ensureValidSelection)
        .onChange(of: clipboardStore.searchText) { _ in
            selectedID = clipboardStore.filteredEntries.first?.id
        }
        .onChange(of: clipboardStore.filteredEntries.map(\.id)) { _ in
            ensureValidSelection()
        }
    }

    private var entryList: some View {
        List(selection: $selectedID) {
            ForEach(clipboardStore.filteredEntries) { entry in
                HStack(spacing: 10) {
                    Image(systemName: entry.type.symbol)
                        .frame(width: 22)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.displayText.replacingOccurrences(of: "\n", with: " "))
                            .font(.body)
                            .lineLimit(2)
                        HStack {
                            Text(entry.type.title)
                            Text("•")
                            Text(entry.sourceApp)
                            Spacer()
                            Text(entry.createdAt, style: .time)
                        }.font(.caption).foregroundColor(.secondary)
                    }
                    if entry.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .padding(.vertical, 3)
                .tag(entry.id)
                .contextMenu {
                    Button("复制") { clipboardStore.copy(entry); copied() }
                    Button("固定为便签") { pin(entry) }.disabled(entry.isPinned)
                    Button("AI 整理") { generateAI(for: entry) }.disabled(entry.type == .image || entry.type == .files)
                    Divider()
                    Button("删除") { clipboardStore.delete(entry) }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: false))
    }

    @ViewBuilder
    private var preview: some View {
        if let entry = selected {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label(entry.type.title, systemImage: entry.type.symbol)
                            .font(.title3.weight(.semibold))
                        Spacer()
                        Text(entry.createdAt, style: .date)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                    if entry.type == .image, let path = entry.imagePath, let image = NSImage(contentsOfFile: path) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                }
                .padding(20)
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
            HStack(spacing: 12) {
                Picker("处理方式", selection: $aiKind) {
                    ForEach(AITransformKind.allCases) { kind in
                        Label(kind.title, systemImage: kind.symbol).tag(kind)
                    }
                }
                .frame(width: 210)
                if aiKind == .translate {
                    TextField("目标语言", text: $aiTargetLanguage)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 150)
                }
                Spacer()
                Button("生成方案") { generateAI(for: entry, append: false) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(aiService.isLoading)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("补充要求（可选）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("例如：写得更简洁，保留所有数字，语气适合发给客户", text: $aiRequirement)
                    .textFieldStyle(.roundedBorder)
            }
            if aiService.isLoading {
                VStack(spacing: 14) {
                    ProgressView(aiKind == .translate ? "正在生成翻译方案…" : "正在生成\(aiKind.title)方案…")
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
            HStack {
                Label("AI 生成内容可能有误，保存前请检查。", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if !aiActions.isEmpty && !aiService.isLoading {
                    Button("继续生成", systemImage: "arrow.clockwise") {
                        generateAI(for: entry, append: true)
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 680, height: 520)
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        let items = clipboardStore.filteredEntries
        guard !items.isEmpty else {
            selectedID = nil
            return
        }
        let currentIndex = selectedID.flatMap { id in
            items.firstIndex(where: { $0.id == id })
        } ?? 0
        switch direction {
        case .down: selectedID = items[min(currentIndex + 1, items.count - 1)].id
        case .up: selectedID = items[max(currentIndex - 1, 0)].id
        default: break
        }
    }

    private func ensureValidSelection() {
        let items = clipboardStore.filteredEntries
        guard let selectedID, items.contains(where: { $0.id == selectedID }) else {
            self.selectedID = items.first?.id
            return
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
        aiKind = .smart
        aiRequirement = ""
        aiTargetLanguage = "简体中文"
        aiActions = []
        generateAI(for: entry, append: false)
    }

    private func generateAI(for entry: ClipboardEntry, append: Bool) {
        Task {
            let generated = await aiService.generateActions(
                for: entry.text ?? entry.displayText,
                kind: aiKind,
                requirement: aiRequirement,
                targetLanguage: aiTargetLanguage
            )
            if append {
                let unique = generated.map { action in
                    AIPinAction(
                        id: "\(action.id)-\(UUID().uuidString)",
                        label: action.label,
                        prompt: action.prompt,
                        title: action.title,
                        contentMarkdown: action.contentMarkdown
                    )
                }
                aiActions.append(contentsOf: unique)
            } else {
                aiActions = generated
            }
        }
    }

    private func applyAI(_ action: AIPinAction, to entry: ClipboardEntry) {
        Task {
            let source = entry.text ?? entry.displayText
            let content = action.prompt == "保留原始内容" || action.contentMarkdown != source
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
