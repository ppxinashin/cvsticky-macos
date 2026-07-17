import SwiftUI

struct MainView: View {
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var clipboardStore: ClipboardStore
    @State private var selection: String?
    @State private var search = ""
    @State private var showingTrash = false

    private var visibleNotes: [Note] {
        let source = showingTrash ? noteStore.deletedNotes : noteStore.notes
        guard !search.isEmpty else { return source }
        return source.filter {
            $0.title.localizedCaseInsensitiveContains(search)
                || $0.markdown.localizedCaseInsensitiveContains(search)
                || $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(search) })
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $showingTrash) {
                Section("剪贴笺") {
                    Button {
                        showingTrash = false
                        selection = noteStore.create()?.id
                    } label: {
                        Label("新建便签", systemImage: "square.and.pencil")
                    }
                    .buttonStyle(.plain)

                    Label("全部便签", systemImage: "note.text")
                        .badge(noteStore.notes.count)
                        .onTapGesture { showingTrash = false }
                    Label("最近删除", systemImage: "trash")
                        .badge(noteStore.deletedNotes.count)
                        .onTapGesture { showingTrash = true; selection = nil }
                }

                Section("剪贴板") {
                    Label("历史记录", systemImage: "clipboard")
                        .badge(clipboardStore.entries.count)
                }
            }
            .navigationTitle("CVSticky")
        } content: {
            List(visibleNotes, selection: $selection) { note in
                VStack(alignment: .leading, spacing: 5) {
                    Text(note.title).font(.headline).lineLimit(1)
                    Text(note.markdown.isEmpty ? "空白便签" : note.markdown)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Text(note.updatedAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .tag(note.id)
                .contextMenu {
                    if showingTrash {
                        Button("恢复") { noteStore.restore(note) }
                        Button("彻底删除", role: .destructive) { noteStore.deletePermanently(note) }
                    } else {
                        Button("复制全文") { clipboardStore.copy(note.markdown) }
                        Button("移到最近删除", role: .destructive) { noteStore.moveToTrash(note) }
                    }
                }
            }
            .searchable(text: $search, prompt: "搜索便签")
            .navigationTitle(showingTrash ? "最近删除" : "便签")
        } detail: {
            if let note = visibleNotes.first(where: { $0.id == selection }), !showingTrash {
                NoteEditorView(note: note)
            } else {
                ContentUnavailableView(
                    "选择一个便签",
                    systemImage: "note.text",
                    description: Text("从列表中选择便签，或创建一条新便签。")
                )
            }
        }
        .frame(minWidth: 900, minHeight: 620)
    }
}
