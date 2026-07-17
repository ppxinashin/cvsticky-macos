import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct NoteEditorView: View {
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var clipboardStore: ClipboardStore
    @Environment(\.colorScheme) private var colorScheme
    let note: Note

    @StateObject private var bridge = MarkdownEditorBridge()
    @State private var title = ""
    @State private var markdown = ""
    @State private var tags = ""
    @State private var color: String?
    @State private var editing = false
    @State private var showLink = false
    @State private var linkURL = "https://"
    @State private var status = ""

    private let colors: [(String, String?)] = [
        ("无", nil), ("黄", "#F8D86A"), ("绿", "#78D6A0"),
        ("蓝", "#70B7FF"), ("紫", "#BF9CFF"), ("红", "#FF8A8A")
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if editing {
                editorToolbar
                Divider()
                HSplitView {
                    MarkdownTextEditor(text: $markdown, bridge: bridge)
                        .frame(minWidth: 340)
                    MarkdownPreview(
                        markdown: markdown,
                        note: note,
                        darkMode: colorScheme == .dark,
                        onTaskToggle: toggleTask
                    )
                    .frame(minWidth: 300)
                }
            } else {
                MarkdownPreview(
                    markdown: markdown,
                    note: note,
                    darkMode: colorScheme == .dark,
                    onTaskToggle: toggleTask
                )
            }
        }
        .background(noteBackground)
        .onAppear(perform: load)
        .onChange(of: note.id) { _ in load() }
        .sheet(isPresented: $showLink) { linkSheet }
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
                Button("取消") { load(); editing = false }
                Button("保存") { save(); editing = false }
                    .keyboardShortcut("s", modifiers: .command)
            } else {
                Button(action: { clipboardStore.copy(markdown); status = "已复制" }) {
                    Image(systemName: "doc.on.doc")
                }
                .help("复制全文")
                Button("编辑") { editing = true }
                    .keyboardShortcut("e", modifiers: .command)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    private var editorToolbar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                tool("bold", "粗体") { bridge.wrap("**") }
                tool("italic", "斜体") { bridge.wrap("*") }
                tool("underline", "下划线") { bridge.wrap("++") }
                tool("strikethrough", "删除线") { bridge.wrap("~~") }
                Divider().frame(height: 18)
                tool("textformat.size.larger", "一级标题") { bridge.heading(1) }
                tool("textformat.size", "二级标题") { bridge.heading(2) }
                tool("textformat.size.smaller", "三级标题") { bridge.heading(3) }
                Divider().frame(height: 18)
                tool("list.bullet", "无序列表") { bridge.linePrefix("- ") }
                tool("list.number", "有序列表") { bridge.linePrefix("1. ") }
                tool("checklist", "任务列表") { bridge.linePrefix("- [ ] ") }
                tool("text.quote", "引用") { bridge.linePrefix("> ") }
                Divider().frame(height: 18)
                tool("link", "链接") { showLink = true }
                tool("photo", "图片") { insertImage() }
                tool("tablecells", "表格") {
                    bridge.insert("\n| 列 1 | 列 2 | 列 3 |\n| --- | --- | --- |\n| 内容 | 内容 | 内容 |\n")
                }
                tool("sum", "公式") { bridge.insert("$E=mc^2$") }
                tool("point.3.connected.trianglepath.dotted", "Mermaid") {
                    bridge.insert("\n```mermaid\ngraph TD\nA[开始] --> B[完成]\n```\n")
                }
                Spacer()
            }
            HStack(spacing: 8) {
                Text("颜色").foregroundColor(.secondary)
                ForEach(colors, id: \.0) { item in
                    Button(action: { color = item.1 }) {
                        Circle()
                            .fill(item.1.flatMap { NSColor(hex: $0) }.map(Color.init) ?? Color.secondary.opacity(0.2))
                            .frame(width: 18, height: 18)
                            .overlay(Circle().stroke(color == item.1 ? Color.accentColor : Color.clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .help(item.0)
                }
                Divider().frame(height: 18)
                Image(systemName: "tag")
                TextField("标签，以逗号分隔", text: $tags)
                    .textFieldStyle(.plain)
                    .frame(maxWidth: 320)
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(VisualEffectView(material: .headerView))
    }

    private func tool(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).frame(width: 18, height: 18) }
            .buttonStyle(.plain)
            .padding(5)
            .contentShape(Rectangle())
            .help(help)
    }

    private var linkSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("插入链接").font(.headline)
            TextField("https://example.com", text: $linkURL)
            HStack {
                Spacer()
                Button("取消") { showLink = false }
                Button("插入") {
                    bridge.insert("[链接](\(linkURL))")
                    showLink = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 420)
    }

    private var noteBackground: Color {
        guard let color, let nsColor = NSColor(hex: color) else { return Color.clear }
        return Color(nsColor: nsColor).opacity(colorScheme == .dark ? 0.16 : 0.12)
    }

    private func load() {
        title = note.title
        markdown = note.markdown
        tags = note.tags.joined(separator: ", ")
        color = note.color
        status = ""
    }

    private func save() {
        var updated = note
        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Untitled"
        updated.markdown = markdown
        updated.tags = tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        updated.color = color
        updated.updatedAt = Date()
        status = noteStore.save(updated) ? "已保存" : "保存失败"
    }

    private func insertImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let path = try noteStore.addImage(url, to: note)
            bridge.insert("![\(url.deletingPathExtension().lastPathComponent)](\(path))")
        } catch {
            status = "图片保存失败"
        }
    }

    private func toggleTask(index: Int, checked: Bool) {
        let pattern = #"(?m)^(\s*[-*+]\s+\[)([ xX])(\]\s+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let range = NSRange(markdown.startIndex..., in: markdown)
        let matches = regex.matches(in: markdown, range: range)
        guard matches.indices.contains(index), let stateRange = Range(matches[index].range(at: 2), in: markdown) else { return }
        markdown.replaceSubrange(stateRange, with: checked ? "x" : " ")
        var updated = note
        updated.markdown = markdown
        updated.updatedAt = Date()
        _ = noteStore.save(updated)
    }
}
