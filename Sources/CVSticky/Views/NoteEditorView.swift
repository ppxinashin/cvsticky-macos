import AppKit
import SwiftUI

struct NoteEditorView: View {
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var clipboardStore: ClipboardStore
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.colorScheme) private var colorScheme
    let note: Note
    let startsEditing: Bool
    let onInitialEditingConsumed: () -> Void
    let onCancelNewNote: () -> Void

    @State private var title = ""
    @State private var markdown = ""
    @State private var tags = ""
    @State private var color: String?
    @State private var editing = false
    @State private var status = ""
    @State private var showingTablePicker = false
    @State private var tableRows = 3
    @State private var tableColumns = 3
    @State private var hoveredTableRows = 3
    @State private var hoveredTableColumns = 3
    @State private var consumedInitialEditing = false
    @State private var isNewDraft = false

    init(
        note: Note,
        startsEditing: Bool = false,
        onInitialEditingConsumed: @escaping () -> Void = {},
        onCancelNewNote: @escaping () -> Void = {}
    ) {
        self.note = note
        self.startsEditing = startsEditing
        self.onInitialEditingConsumed = onInitialEditingConsumed
        self.onCancelNewNote = onCancelNewNote
    }

    private let categoryColors: [(name: String, hex: String?)] = [
        ("无颜色", nil),
        ("黄色", "#F8D86A"),
        ("绿色", "#78D6A0"),
        ("蓝色", "#70B7FF"),
        ("紫色", "#BF9CFF"),
        ("红色", "#FF8A8A")
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if editing {
                metadataToolbar
                Divider()
                formattingToolbar
                Divider()
            }
            MarkdownWYSIWYGEditor(
                markdown: $markdown,
                note: note,
                darkMode: colorScheme == .dark,
                chromeBackgroundHex: editorChromeBackgroundHex,
                accentHex: settings.effectiveAccentHex,
                editable: editing,
                onTaskToggle: toggleTask,
                onError: { status = $0 }
            )
            .id("\(note.id)-\(colorScheme == .dark ? "dark" : "light")")
        }
        .background(noteBackground)
        .onAppear {
            load()
            beginInitialEditingIfNeeded()
        }
        .onChange(of: note.id) { _ in
            consumedInitialEditing = false
            load()
            beginInitialEditingIfNeeded()
        }
        .onChange(of: startsEditing) { _ in beginInitialEditingIfNeeded() }
        .onChange(of: note.updatedAt) { _ in
            guard !editing,
                  let latest = noteStore.notes.first(where: { $0.id == note.id }) else { return }
            let latestTags = latest.tags.joined(separator: ", ")
            guard latest.title != title
                    || latest.markdown != markdown
                    || latestTags != tags
                    || latest.color != color else { return }
            load(from: latest)
        }
    }

    private func beginInitialEditingIfNeeded() {
        guard startsEditing, !consumedInitialEditing else { return }
        editing = true
        isNewDraft = true
        consumedInitialEditing = true
        onInitialEditingConsumed()
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if editing {
                    TextField("便签标题", text: $title)
                        .font(.title2.bold())
                        .textFieldStyle(.plain)
                } else {
                    Text(title.isEmpty ? "Untitled" : title)
                        .font(.title2.bold())
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Text(note.updatedAt, style: .date)
                    if !status.isEmpty { Text("• \(status)") }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            Spacer()
            if editing {
                Button("取消") { cancelEditing() }
                    .buttonStyle(.bordered)
                Button("保存") {
                    if save() { editing = false }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("s", modifiers: .command)
            } else {
                Button(action: { clipboardStore.copy(markdown); status = "已复制" }) {
                    Label("复制", systemImage: "doc.on.doc")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("复制全文")
                Button(action: { editing = true }) {
                    Label("编辑", systemImage: "square.and.pencil")
                }
                .buttonStyle(.borderless)
                .help("编辑（⌘E）")
                .keyboardShortcut("e", modifiers: .command)
            }
        }
        .controlSize(.regular)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var metadataToolbar: some View {
        HStack(spacing: 10) {
            Text("颜色")
                .foregroundStyle(.secondary)
            ForEach(categoryColors, id: \.name) { item in
                Button(action: { color = item.hex }) {
                    ZStack {
                        Circle()
                            .fill(item.hex.flatMap(NSColor.init(hex:)).map(Color.init) ?? Color.clear)
                            .overlay(
                                Circle().stroke(
                                    item.hex == nil ? Color.secondary : Color.clear,
                                    lineWidth: 1
                                )
                            )
                        if item.hex == nil {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 18, height: 18)
                    .padding(4)
                    .overlay(
                        Circle().stroke(
                            color == item.hex ? Color.accentColor : Color.clear,
                            lineWidth: 2
                        )
                    )
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(item.name)
                .accessibilityLabel(item.name)
                .accessibilityValue(color == item.hex ? "已选择" : "未选择")
            }
            Divider().frame(height: 18)
            Image(systemName: "tag")
                .foregroundStyle(.secondary)
            TextField("标签，以逗号分隔", text: $tags)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 320)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var formattingToolbar: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(1...6, id: \.self) { level in
                    Button("\(chineseHeading(level))级标题　⌥\(level)") {
                        sendEditorCommand("heading\(level)")
                    }
                }
                Divider()
                Button("粗体　⌘B") { sendEditorCommand("bold") }
                Button("斜体　⌘I") { sendEditorCommand("italic") }
                Button("下划线　⌘U") { sendEditorCommand("underline") }
                Button("删除线　⌘⇧X") { sendEditorCommand("strike") }
                Button("行内代码　⌘E") { sendEditorCommand("code") }
            } label: {
                formattingMenuLabel("格式", systemImage: "textformat")
            }
            .menuIndicator(.hidden)
            .overlay(alignment: .trailing) {
                formattingMenuIndicator
            }

            Menu {
                Button("无序列表　⌘⇧8") { sendEditorCommand("bulletList") }
                Button("有序列表　⌘⇧7") { sendEditorCommand("orderedList") }
                Button("任务列表") { sendEditorCommand("taskList") }
                Button("引用") { sendEditorCommand("quote") }
            } label: {
                formattingMenuLabel("列表", systemImage: "list.bullet")
            }
            .menuIndicator(.hidden)
            .overlay(alignment: .trailing) {
                formattingMenuIndicator
            }

            Menu {
                Button("表格…") { showingTablePicker = true }
                Button("Mermaid 流程图") { sendEditorCommand("mermaid") }
                Button("行内公式 $…$") { sendEditorCommand("math") }
                Divider()
                Button("链接　⌘K") { sendEditorCommand("link") }
                Button("图片…") { sendEditorCommand("image") }
            } label: {
                formattingMenuLabel("插入", systemImage: "plus")
            }
            .menuIndicator(.hidden)
            .overlay(alignment: .trailing) {
                formattingMenuIndicator
            }
            .popover(isPresented: $showingTablePicker, arrowEdge: .bottom) {
                tableSizePicker
            }

            Spacer(minLength: 0)
            Text("⌘/  插入命令")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .controlSize(.regular)
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(.bar)
    }

    private func formattingMenuLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Label(title, systemImage: systemImage)
            Spacer(minLength: 36)
        }
        .frame(minWidth: 128)
    }

    private var formattingMenuIndicator: some View {
        Image(systemName: "chevron.down")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(formattingMenuIndicatorForeground)
            .frame(width: 20, height: 20)
            .background(
                Color(nsColor: settings.accentColor),
                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
            )
            .padding(.trailing, 5)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var formattingMenuIndicatorForeground: Color {
        guard let color = settings.accentColor.usingColorSpace(.sRGB) else { return .white }
        let luminance = 0.2126 * color.redComponent
            + 0.7152 * color.greenComponent
            + 0.0722 * color.blueComponent
        return luminance > 0.62 ? Color.black.opacity(0.82) : .white
    }

    private var tableSizePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(hoveredTableRows) 行 × \(hoveredTableColumns) 列")
                .font(.headline)
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(20), spacing: 4), count: 8),
                spacing: 4
            ) {
                ForEach(0..<64, id: \.self) { index in
                    let row = index / 8 + 1
                    let column = index % 8 + 1
                    Button {
                        insertTable(rows: row, columns: column)
                    } label: {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(row <= hoveredTableRows && column <= hoveredTableColumns ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(row <= hoveredTableRows && column <= hoveredTableColumns ? Color.accentColor : Color.secondary.opacity(0.45))
                            )
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .help("\(row) 行 × \(column) 列")
                    .onHover { hovering in
                        if hovering {
                            hoveredTableRows = row
                            hoveredTableColumns = column
                        }
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 16) {
                Stepper("行数：\(tableRows)", value: $tableRows, in: 1...50)
                Stepper("列数：\(tableColumns)", value: $tableColumns, in: 1...50)
            }
            Button("插入表格") {
                insertTable(rows: tableRows, columns: tableColumns)
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .frame(width: 260)
        .onAppear {
            hoveredTableRows = tableRows
            hoveredTableColumns = tableColumns
        }
    }

    private func insertTable(rows: Int, columns: Int) {
        tableRows = rows
        tableColumns = columns
        sendEditorCommand("table", row: rows, column: columns)
        showingTablePicker = false
    }

    private func sendEditorCommand(_ command: String, row: Int? = nil, column: Int? = nil) {
        NotificationCenter.default.post(
            name: .markdownEditorCommand,
            object: MarkdownEditorCommandRequest(
                noteID: note.id,
                command: command,
                row: row,
                column: column
            )
        )
    }

    private func chineseHeading(_ level: Int) -> String {
        ["", "一", "二", "三", "四", "五", "六"][level]
    }

    private func subscriptDigit(_ value: Int) -> String {
        ["", "₁", "₂", "₃", "₄", "₅", "₆"][value]
    }

    private var editorChromeBackgroundHex: String {
        colorScheme == .dark ? "#292929" : "#FFFFFF"
    }

    private var noteBackground: Color {
        guard let color, let nsColor = NSColor(hex: color) else { return Color.clear }
        return Color(nsColor: nsColor).opacity(colorScheme == .dark ? 0.16 : 0.12)
    }

    private func load(from source: Note? = nil) {
        let source = source ?? note
        title = source.title
        markdown = source.markdown
        tags = source.tags.joined(separator: ", ")
        color = source.color
        status = ""
    }

    @discardableResult
    private func save() -> Bool {
        var updated = note
        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Untitled"
        updated.markdown = markdown
        updated.tags = tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        updated.color = color
        updated.updatedAt = Date()
        guard noteStore.save(updated) else {
            status = "保存失败"
            return false
        }
        isNewDraft = false
        if let saved = noteStore.notes.first(where: { $0.id == note.id }) {
            title = saved.title
            markdown = saved.markdown
            tags = saved.tags.joined(separator: ", ")
            color = saved.color
        }
        status = "已保存"
        return true
    }

    private func cancelEditing() {
        if isNewDraft {
            noteStore.deletePermanently(note)
            onCancelNewNote()
            return
        }
        load()
        editing = false
    }

    private func toggleTask(markdown updatedMarkdown: String) {
        markdown = updatedMarkdown
        var updated = note
        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Untitled"
        updated.markdown = updatedMarkdown
        updated.tags = tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        updated.color = color
        updated.updatedAt = Date()
        status = noteStore.saveTaskState(updated) ? "已保存" : "保存失败"
    }
}

struct MarkdownEditorCommandRequest: Equatable, Identifiable {
    let id = UUID()
    let noteID: String?
    let command: String
    var row: Int?
    var column: Int?
}

extension Notification.Name {
    static let markdownEditorCommand = Notification.Name("CVSticky.MarkdownEditorCommand")
}
