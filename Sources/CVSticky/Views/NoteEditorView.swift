import SwiftUI

struct NoteEditorView: View {
    @EnvironmentObject private var noteStore: NoteStore
    let note: Note

    @State private var title = ""
    @State private var markdown = ""
    @State private var tags = ""
    @State private var editing = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if editing {
                    TextField("便签标题", text: $title)
                        .font(.title2.bold())
                        .textFieldStyle(.plain)
                } else {
                    Text(title).font(.title2.bold()).lineLimit(1)
                }
                Spacer()
                if editing {
                    Button("取消") { load(); editing = false }
                    Button("保存") { save(); editing = false }
                        .keyboardShortcut("s", modifiers: .command)
                } else {
                    Button("编辑", systemImage: "pencil") { editing = true }
                }
            }
            .padding()

            Divider()

            if editing {
                VStack(spacing: 0) {
                    TextEditor(text: $markdown)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding()
                    Divider()
                    TextField("标签，以逗号分隔", text: $tags)
                        .textFieldStyle(.plain)
                        .padding()
                }
            } else {
                ScrollView {
                    Text(markdown.isEmpty ? "空白便签" : markdown)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(24)
                }
            }
        }
        .onAppear(perform: load)
        .onChange(of: note.id) { _, _ in load() }
    }

    private func load() {
        title = note.title
        markdown = note.markdown
        tags = note.tags.joined(separator: ", ")
    }

    private func save() {
        var updated = note
        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : title
        updated.markdown = markdown
        updated.tags = tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        updated.updatedAt = .now
        _ = noteStore.save(updated)
    }
}
