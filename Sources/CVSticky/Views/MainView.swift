import AppKit
import SwiftUI

struct MainView: View {
    private let sidebarMaximumWidth: CGFloat = 240

    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var clipboardStore: ClipboardStore
    @EnvironmentObject private var settings: SettingsStore

    @State private var selection: String?
    @State private var search = ""
    @State private var showingTrash = false
    @State private var selectedTag: String?
    @State private var selectedColor: String?
    @State private var sidebarSelection: SidebarDestination? = .notes
    @State private var sidebarVisible = true
    @State private var pendingPermanentDelete: Note?
    @State private var showingClearTrashConfirmation = false
    @State private var newlyCreatedNoteID: String?

    private var visibleNotes: [Note] {
        let source = showingTrash ? noteStore.deletedNotes : noteStore.notes
        return source.filter { note in
            if let selectedTag, !note.tags.contains(selectedTag) { return false }
            if let selectedColor, note.color != selectedColor { return false }
            guard !search.isEmpty else { return true }
            return note.title.localizedCaseInsensitiveContains(search)
                || note.markdown.localizedCaseInsensitiveContains(search)
                || note.tags.contains(where: { $0.localizedCaseInsensitiveContains(search) })
        }
    }

    private var allTags: [String] {
        Array(Set(noteStore.notes.flatMap(\.tags))).sorted()
    }

    var body: some View {
        HStack(spacing: 0) {
            if sidebarVisible {
                sidebar
                    .frame(width: sidebarMaximumWidth)
                Divider()
            }

            HSplitView {
                noteList.frame(minWidth: 240, idealWidth: 280, maxWidth: 380)
                detail.frame(minWidth: 430)
            }
        }
        .frame(minWidth: 900, minHeight: 620)
        .accentColor(Color(nsColor: settings.accentColor))
        .searchable(text: $search, placement: .toolbar, prompt: "搜索便签")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 10) {
                    Button(action: toggleSidebar) {
                        Label(sidebarVisible ? "隐藏边栏" : "显示边栏", systemImage: "sidebar.left")
                    }
                    .help("\(sidebarVisible ? "隐藏" : "显示")边栏（⌥⌘S）")

                    Button(action: createNote) {
                        Label("新建便签", systemImage: "square.and.pencil")
                    }
                    .help("新建便签（⌘N）")

                    Button {
                        NotificationCenter.default.post(name: .cvstickyShowSettings, object: nil)
                    } label: {
                        Label("设置", systemImage: "gearshape")
                    }
                    .help("设置（⌘,）")
                }
            }
        }
        .alert(item: $pendingPermanentDelete) { note in
            Alert(
                title: Text("彻底删除“\(note.title)”？"),
                message: Text("此操作无法撤销。"),
                primaryButton: .destructive(Text("彻底删除")) {
                    noteStore.deletePermanently(note)
                },
                secondaryButton: .cancel()
            )
        }
        .alert("清空最近删除？", isPresented: $showingClearTrashConfirmation) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                selection = nil
                noteStore.emptyTrash()
            }
        } message: {
            Text("将彻底删除最近删除中的 \(noteStore.deletedNotes.count) 条便签，此操作无法撤销。")
        }
        .onReceive(NotificationCenter.default.publisher(for: .cvstickyNewNote)) { _ in
            createNote()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cvstickyToggleSidebar)) { _ in
            toggleSidebar()
        }
        .onChange(of: sidebarSelection) { destination in
            if let destination { applySidebarSelection(destination) }
        }
    }

    private var sidebar: some View {
        List(selection: $sidebarSelection) {
            Section("便签") {
                sidebarRow("全部便签", symbol: "note.text", count: noteStore.notes.count)
                    .tag(SidebarDestination.notes)
                sidebarRow("最近删除", symbol: "trash", count: noteStore.deletedNotes.count)
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button("清空最近删除…", role: .destructive) {
                            showingClearTrashConfirmation = true
                        }
                        .disabled(noteStore.deletedNotes.isEmpty)
                    }
                    .tag(SidebarDestination.trash)
            }

            if !allTags.isEmpty {
                Section("标签") {
                    ForEach(allTags, id: \.self) { tag in
                        sidebarRow(tag, symbol: "tag", count: nil)
                            .tag(SidebarDestination.tag(tag))
                    }
                }
            }

            Section("颜色") {
                ForEach(noteColors, id: \.hex) { item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(nsColor: NSColor(hex: item.hex)!))
                            .frame(width: 10, height: 10)
                        Text(item.name)
                    }
                    .tag(SidebarDestination.color(item.hex))
                    .accessibilityLabel("\(item.name)便签")
                }
            }
        }
        .listStyle(.sidebar)
    }

    private var noteList: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(currentSectionTitle)
                        .font(.title2.weight(.semibold))
                    Text("\(visibleNotes.count) 条记录")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.bar)
            .accessibilityElement(children: .combine)

            Divider()

            Group {
                if visibleNotes.isEmpty {
                    EmptyStateView(
                        title: showingTrash ? "最近删除为空" : "没有找到便签",
                        symbol: showingTrash ? "trash" : "note.text",
                        detail: "尝试更换关键词或筛选条件"
                    )
                } else {
                    List(selection: $selection) {
                        ForEach(noteYears, id: \.self) { year in
                            Section {
                                ForEach(notes(in: year)) { note in
                                    noteRow(note).tag(note.id)
                                }
                            } header: {
                                Text(verbatim: "\(year)年")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .textCase(nil)
                                    .padding(.top, 4)
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private var detail: some View {
        if let note = noteForSelection, !showingTrash {
            NoteEditorView(
                note: note,
                startsEditing: note.id == newlyCreatedNoteID,
                onInitialEditingConsumed: {
                    if newlyCreatedNoteID == note.id {
                        newlyCreatedNoteID = nil
                    }
                },
                onCancelNewNote: {
                    if selection == note.id {
                        selection = nil
                    }
                    if newlyCreatedNoteID == note.id {
                        newlyCreatedNoteID = nil
                    }
                }
            )
                .id(note.id)
        } else {
            EmptyStateView(
                title: "选择一个便签",
                symbol: "note.text",
                detail: "从列表中选择便签，或创建一条新便签。"
            )
        }
    }

    private var noteForSelection: Note? {
        noteStore.notes.first(where: { $0.id == selection })
    }

    private func noteRow(_ note: Note) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(note.title)
                .font(.body.weight(.semibold))
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Self.noteListDateFormatter.string(from: note.updatedAt))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                Text(listPreview(note))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Divider()
                .opacity(selection == note.id ? 0 : 1)
                .padding(.trailing, 12)
        }
        .contextMenu { noteContextMenu(note) }
    }

    @ViewBuilder
    private func noteContextMenu(_ note: Note) -> some View {
        if showingTrash {
            Button("恢复") { noteStore.restore(note) }
            Divider()
            Button("彻底删除…", role: .destructive) { pendingPermanentDelete = note }
        } else {
            Button("打开") { selection = note.id }
            Button("复制全文") { clipboardStore.copy(note.markdown) }
            Divider()
            Button("移到最近删除") { noteStore.moveToTrash(note); if selection == note.id { selection = nil } }
        }
    }

    private func sidebarRow(_ title: String, symbol: String, count: Int?) -> some View {
        Label {
            HStack {
                Text(title).lineLimit(1)
                Spacer()
                if let count {
                    Text("\(count)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        } icon: {
            Image(systemName: symbol)
        }
    }

    private func preview(_ note: Note) -> String {
        note.markdown
            .replacingOccurrences(of: #"!\[[^\]]*\]\([^)]*\)"#, with: "[图片]", options: .regularExpression)
            .replacingOccurrences(of: #"[#>*_`]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty ?? "空白便签"
    }

    private func listPreview(_ note: Note) -> String {
        let value = preview(note)
        return value == "空白便签" ? "无更多文本" : value
    }

    private var noteYears: [Int] {
        Set(visibleNotes.map { Calendar.current.component(.year, from: $0.updatedAt) })
            .sorted(by: >)
    }

    private func notes(in year: Int) -> [Note] {
        visibleNotes.filter {
            Calendar.current.component(.year, from: $0.updatedAt) == year
        }
    }

    private func createNote() {
        showingTrash = false
        selectedTag = nil
        selectedColor = nil
        sidebarSelection = .notes
        if let note = noteStore.create() {
            newlyCreatedNoteID = note.id
            selection = note.id
        }
    }

    private func toggleSidebar() {
        withAnimation(.easeInOut(duration: 0.18)) {
            sidebarVisible.toggle()
        }
    }

    private var currentSectionTitle: String {
        switch sidebarSelection ?? .notes {
        case .notes: return "便签"
        case .trash: return "最近删除"
        case .tag(let tag): return tag
        case .color(let hex): return noteColors.first(where: { $0.hex == hex })?.name ?? "颜色"
        }
    }

    private var noteColors: [(name: String, hex: String)] {
        [("黄色", "#F8D86A"), ("绿色", "#78D6A0"), ("蓝色", "#70B7FF"), ("紫色", "#BF9CFF"), ("红色", "#FF8A8A")]
    }

    private func applySidebarSelection(_ destination: SidebarDestination) {
        switch destination {
        case .notes:
            showingTrash = false; selectedTag = nil; selectedColor = nil
        case .trash:
            showingTrash = true; selection = nil; selectedTag = nil; selectedColor = nil
        case .tag(let tag):
            showingTrash = false; selectedTag = tag; selectedColor = nil
        case .color(let color):
            showingTrash = false; selectedTag = nil; selectedColor = color
        }
    }

    private static let noteListDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
}

private enum SidebarDestination: Hashable {
    case notes
    case trash
    case tag(String)
    case color(String)
}

struct SearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = placeholder
        field.sendsSearchStringImmediately = true
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        if field.stringValue != text { field.stringValue = text }
        field.placeholderString = placeholder
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            text.wrappedValue = field.stringValue
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let symbol: String
    let detail: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 38)).foregroundColor(.secondary)
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

extension Notification.Name {
    static let cvstickyNewNote = Notification.Name("CVSticky.newNote")
    static let cvstickyToggleSidebar = Notification.Name("CVSticky.toggleSidebar")
    static let cvstickyShowSettings = Notification.Name("CVSticky.showSettings")
}
