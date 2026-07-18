import AppKit
import SwiftUI

struct MainView: View {
    private let sidebarMaximumWidth: CGFloat = 240

    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var clipboardStore: ClipboardStore
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.controlActiveState) private var controlActiveState

    @State private var selection: String?
    @State private var search = ""
    @State private var showingTrash = false
    @State private var selectedTag: String?
    @State private var selectedColor: String?
    @State private var sidebarSelection: SidebarDestination? = .notes
    @State private var sidebarVisible = true
    @State private var pendingAlert: MainAlert?
    @State private var newlyCreatedNoteID: String?
    @FocusState private var focusedColumn: MainColumn?

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
        .tint(Color(nsColor: settings.accentColor))
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
        .alert(item: $pendingAlert, content: alert)
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
                sidebarRow(
                    "全部便签",
                    symbol: "note.text",
                    count: noteStore.notes.count,
                    destination: .notes
                )
                    .tag(SidebarDestination.notes)
                sidebarRow(
                    "最近删除",
                    symbol: "trash",
                    count: noteStore.deletedNotes.count,
                    destination: .trash
                )
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button("清空最近删除…", role: .destructive) {
                            pendingAlert = .clearTrash(count: noteStore.deletedNotes.count)
                        }
                        .disabled(noteStore.deletedNotes.isEmpty)
                    }
                    .tag(SidebarDestination.trash)
            }

            if !allTags.isEmpty {
                Section("标签") {
                    ForEach(allTags, id: \.self) { tag in
                        sidebarRow(tag, symbol: "tag", count: nil, destination: .tag(tag))
                            .tag(SidebarDestination.tag(tag))
                    }
                }
            }

            Section("颜色") {
                ForEach(noteColors, id: \.hex) { item in
                    sidebarColorRow(item.name, hex: item.hex)
                    .tag(SidebarDestination.color(item.hex))
                    .accessibilityLabel("\(item.name)便签")
                }
            }
        }
        .listStyle(.sidebar)
        .focused($focusedColumn, equals: .sidebar)
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
                                        .listRowBackground(Color.clear)
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
                    .focused($focusedColumn, equals: .noteList)
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
        SwipeActionRow(
            actions: noteSwipeActions(for: note),
            isSelected: selection == note.id,
            isSelectionActive: focusedColumn == .noteList,
            rowBackground: Color(nsColor: .controlBackgroundColor),
            onTap: {
                focusedColumn = .noteList
                selection = note.id
            }
        ) {
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
        }
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Divider()
                .opacity(selection == note.id ? 0 : 1)
                .padding(.trailing, 12)
        }
        .contextMenu { noteContextMenu(note) }
    }

    private func noteSwipeActions(for note: Note) -> [SwipeRowAction] {
        if showingTrash {
            return [
                SwipeRowAction(title: "恢复便签", systemImage: "arrow.uturn.backward", tint: .green) {
                    noteStore.restore(note)
                },
                SwipeRowAction(title: "删除", systemImage: "trash", tint: .red) {
                    pendingAlert = .delete(.permanent(note))
                }
            ]
        }

        return [
            SwipeRowAction(title: "悬浮窗", systemImage: "pin.square", tint: .blue) {
                float(note)
            },
            SwipeRowAction(title: "删除", systemImage: "trash", tint: .red) {
                pendingAlert = .delete(.trash(note))
            }
        ]
    }

    @ViewBuilder
    private func noteContextMenu(_ note: Note) -> some View {
        if showingTrash {
            Button("恢复") { noteStore.restore(note) }
            Divider()
            Button("删除…", role: .destructive) { pendingAlert = .delete(.permanent(note)) }
        } else {
            Button("打开") { selection = note.id }
            Button("悬浮窗") { float(note) }
            Button("复制全文") { clipboardStore.copy(note.markdown) }
            Divider()
            Button("删除…", role: .destructive) { pendingAlert = .delete(.trash(note)) }
        }
    }

    private func sidebarRow(
        _ title: String,
        symbol: String,
        count: Int?,
        destination: SidebarDestination
    ) -> some View {
        styledSidebarRow(destination: destination) {
            Label {
                HStack {
                    Text(title).lineLimit(1)
                    Spacer()
                    if let count {
                        Text("\(count)")
                            .foregroundStyle(sidebarSecondaryColor(for: destination))
                            .monospacedDigit()
                    }
                }
            } icon: {
                Image(systemName: symbol)
            }
        }
    }

    private func sidebarColorRow(_ title: String, hex: String) -> some View {
        let destination = SidebarDestination.color(hex)
        return styledSidebarRow(destination: destination) {
            HStack {
                Circle()
                    .fill(Color(nsColor: NSColor(hex: hex)!))
                    .frame(width: 10, height: 10)
                Text(title)
            }
        }
    }

    private func styledSidebarRow<Content: View>(
        destination: SidebarDestination,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let selected = sidebarSelection == destination
        let emphasized = selected && hasEmphasizedSidebarSelection
        return content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .foregroundStyle(
                emphasized
                    ? Color(nsColor: .alternateSelectedControlTextColor)
                    : Color.primary
            )
            .background {
                ZStack {
                    if selected {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(
                                emphasized
                                    ? Color(nsColor: settings.accentColor)
                                    : Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
                            )
                    }
                    ListSelectionHighlightSuppressor()
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .listRowBackground(Color.clear)
    }

    private var hasEmphasizedSidebarSelection: Bool {
        focusedColumn == .sidebar && controlActiveState == .key
    }

    private func sidebarSecondaryColor(for destination: SidebarDestination) -> Color {
        sidebarSelection == destination && hasEmphasizedSidebarSelection
            ? Color(nsColor: .alternateSelectedControlTextColor).opacity(0.72)
            : Color.secondary
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
            focusedColumn = .noteList
        }
    }

    private func toggleSidebar() {
        withAnimation(.easeInOut(duration: 0.18)) {
            sidebarVisible.toggle()
        }
    }

    private func float(_ note: Note) {
        NotificationCenter.default.post(name: .cvstickyFloatNote, object: note.id)
    }

    private func performDelete(_ request: PendingNoteDelete) {
        switch request {
        case .trash(let note):
            noteStore.moveToTrash(note)
            if selection == note.id { selection = nil }
        case .permanent(let note):
            noteStore.deletePermanently(note)
            if selection == note.id { selection = nil }
        }
    }

    private func alert(_ alert: MainAlert) -> Alert {
        switch alert {
        case .delete(let request):
            return Alert(
                title: Text("删除“\(request.note.title)”？"),
                message: Text(request.message),
                primaryButton: .destructive(Text("删除")) {
                    performDelete(request)
                },
                secondaryButton: .cancel()
            )
        case .clearTrash(let count):
            return Alert(
                title: Text("清空最近删除？"),
                message: Text("将彻底删除最近删除中的 \(count) 条便签，此操作无法撤销。"),
                primaryButton: .destructive(Text("清空")) {
                    selection = nil
                    noteStore.emptyTrash()
                },
                secondaryButton: .cancel()
            )
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

private enum MainColumn: Hashable {
    case sidebar
    case noteList
}

private enum MainAlert: Identifiable {
    case delete(PendingNoteDelete)
    case clearTrash(count: Int)

    var id: String {
        switch self {
        case .delete(let request): return "delete-\(request.id)"
        case .clearTrash(let count): return "clear-trash-\(count)"
        }
    }
}

private enum PendingNoteDelete: Identifiable {
    case trash(Note)
    case permanent(Note)

    var id: String {
        switch self {
        case .trash(let note): return "trash-\(note.id)"
        case .permanent(let note): return "permanent-\(note.id)"
        }
    }

    var note: Note {
        switch self {
        case .trash(let note), .permanent(let note): return note
        }
    }

    var message: String {
        switch self {
        case .trash:
            return "便签会移动到最近删除。如需彻底删除，请到最近删除中彻底删除。"
        case .permanent:
            return "将从最近删除中彻底删除，此操作无法撤销。"
        }
    }
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
    static let cvstickyFloatNote = Notification.Name("CVSticky.floatNote")
}
