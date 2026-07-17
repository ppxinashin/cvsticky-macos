import AppKit
import SwiftUI

struct MainView: View {
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var clipboardStore: ClipboardStore
    @EnvironmentObject private var settings: SettingsStore

    @State private var selection: String?
    @State private var search = ""
    @State private var showingTrash = false
    @State private var selectedTag: String?
    @State private var selectedColor: String?
    @State private var gridMode = false
    @State private var settingsPresented = false
    @State private var pendingPermanentDelete: Note?

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
        HSplitView {
            sidebar.frame(minWidth: 205, idealWidth: 230, maxWidth: 270)
            noteList.frame(minWidth: 270, idealWidth: 340, maxWidth: 460)
            detail.frame(minWidth: 430)
        }
        .frame(minWidth: 900, minHeight: 620)
        .accentColor(Color(nsColor: settings.accentColor))
        .sheet(isPresented: $settingsPresented) { SettingsView() }
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
        .onReceive(NotificationCenter.default.publisher(for: .cvstickyNewNote)) { _ in
            createNote()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "note.text")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text("剪贴笺").font(.headline)
                    Text("CVSticky").font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)

            Button(action: createNote) {
                Label("新建便签", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .padding(.horizontal, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    sectionLabel("便签")
                    navigationButton("全部便签", symbol: "note.text", count: noteStore.notes.count,
                                     selected: !showingTrash && selectedTag == nil && selectedColor == nil) {
                        showingTrash = false; selectedTag = nil; selectedColor = nil
                    }
                    navigationButton("最近删除", symbol: "trash", count: noteStore.deletedNotes.count,
                                     selected: showingTrash) {
                        showingTrash = true; selection = nil; selectedTag = nil; selectedColor = nil
                    }

                    if !allTags.isEmpty {
                        sectionLabel("标签").padding(.top, 10)
                        ForEach(allTags, id: \.self) { tag in
                            navigationButton(tag, symbol: "tag", count: nil,
                                             selected: selectedTag == tag && !showingTrash) {
                                showingTrash = false; selectedTag = tag; selectedColor = nil
                            }
                        }
                    }

                    sectionLabel("颜色").padding(.top, 10)
                    HStack(spacing: 9) {
                        ForEach(["#F8D86A", "#78D6A0", "#70B7FF", "#BF9CFF", "#FF8A8A"], id: \.self) { hex in
                            Button(action: {
                                showingTrash = false
                                selectedColor = selectedColor == hex ? nil : hex
                                selectedTag = nil
                            }) {
                                Circle()
                                    .fill(Color(nsColor: NSColor(hex: hex)!))
                                    .frame(width: 18, height: 18)
                                    .overlay(Circle().stroke(selectedColor == hex ? Color.primary : Color.clear, lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                }
                .padding(.horizontal, 8)
            }

            Spacer(minLength: 0)
            Button(action: { settingsPresented = true }) {
                Label("设置", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(12)
            .adaptiveGlass(radius: 12, material: .menu)
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 16)
        .background(VisualEffectView(material: .sidebar))
    }

    private var noteList: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(showingTrash ? "最近删除" : "便签").font(.title2.bold())
                        Text("\(visibleNotes.count) 条记录").font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: { gridMode.toggle() }) {
                        Image(systemName: gridMode ? "list.bullet" : "square.grid.2x2")
                    }
                    .buttonStyle(.plain)
                }
                SearchField(text: $search, placeholder: "搜索便签")
            }
            .padding(14)
            Divider()

            if visibleNotes.isEmpty {
                EmptyStateView(
                    title: showingTrash ? "最近删除为空" : "没有找到便签",
                    symbol: showingTrash ? "trash" : "note.text",
                    detail: "尝试更换关键词或筛选条件"
                )
            } else if gridMode {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 10)], spacing: 10) {
                        ForEach(visibleNotes) { note in noteCard(note) }
                    }
                    .padding(10)
                }
            } else {
                List(selection: $selection) {
                    ForEach(visibleNotes) { note in noteRow(note).tag(note.id) }
                }
                .listStyle(.inset)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.84))
    }

    @ViewBuilder
    private var detail: some View {
        if let note = noteForSelection, !showingTrash {
            NoteEditorView(note: note)
                .id("\(note.id)-\(note.updatedAt.timeIntervalSince1970)")
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
        VStack(alignment: .leading, spacing: 5) {
            Text(note.title).font(.headline).lineLimit(1)
            Text(preview(note)).foregroundColor(.secondary).lineLimit(2)
            HStack {
                Text(note.updatedAt, style: .date)
                Spacer()
                ForEach(note.tags.prefix(2), id: \.self) { Text("#\($0)") }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 5)
        .contextMenu { noteContextMenu(note) }
    }

    private func noteCard(_ note: Note) -> some View {
        Button(action: { selection = note.id }) {
            VStack(alignment: .leading, spacing: 8) {
                Text(note.title).font(.headline).lineLimit(1)
                Text(preview(note)).foregroundColor(.secondary).lineLimit(4)
                Spacer(minLength: 4)
                Text(note.updatedAt, style: .date).font(.caption).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
            .padding(12)
            .background(note.color.flatMap(NSColor.init(hex:)).map { Color(nsColor: $0).opacity(0.22) } ?? Color.secondary.opacity(0.06))
            .adaptiveGlass(radius: 14, material: .contentBackground)
        }
        .buttonStyle(.plain)
        .contextMenu { noteContextMenu(note) }
    }

    @ViewBuilder
    private func noteContextMenu(_ note: Note) -> some View {
        if showingTrash {
            Button("恢复") { noteStore.restore(note) }
            Button("彻底删除") { pendingPermanentDelete = note }
        } else {
            Button("打开") { selection = note.id }
            Button("复制全文") { clipboardStore.copy(note.markdown) }
            Divider()
            Button("移到最近删除") { noteStore.moveToTrash(note); if selection == note.id { selection = nil } }
        }
    }

    private func navigationButton(
        _ title: String,
        symbol: String,
        count: Int?,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: symbol).frame(width: 20)
                Text(title).lineLimit(1)
                Spacer()
                if let count { Text("\(count)").font(.caption).foregroundColor(.secondary) }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(selected ? Color.accentColor.opacity(0.16) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased()).font(.caption.bold()).foregroundColor(.secondary).padding(.horizontal, 10)
    }

    private func preview(_ note: Note) -> String {
        note.markdown
            .replacingOccurrences(of: #"!\[[^\]]*\]\([^)]*\)"#, with: "[图片]", options: .regularExpression)
            .replacingOccurrences(of: #"[#>*_`]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty ?? "空白便签"
    }

    private func createNote() {
        showingTrash = false
        selectedTag = nil
        selectedColor = nil
        selection = noteStore.create()?.id
    }
}

struct SearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField(placeholder, text: $text).textFieldStyle(.plain)
            if !text.isEmpty {
                Button(action: { text = "" }) { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .adaptiveGlass(radius: 10, material: .menu)
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
}
