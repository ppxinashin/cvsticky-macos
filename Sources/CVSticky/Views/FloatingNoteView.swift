import AppKit
import SwiftUI

struct FloatingNoteView: View {
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var clipboardStore: ClipboardStore
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.colorScheme) private var colorScheme

    let noteID: String
    let fallback: Note
    let onClose: () -> Void

    @State private var markdown = ""
    @State private var status = ""

    private var note: Note {
        noteStore.notes.first(where: { $0.id == noteID }) ?? fallback
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.title.isEmpty ? "Untitled" : note.title)
                        .font(.title2.bold())
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(note.updatedAt, style: .date)
                        if !status.isEmpty { Text("• \(status)") }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: copyMarkdown) {
                    Label("复制", systemImage: "doc.on.doc")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("复制全文")
                Button(action: onClose) {
                    Label("关闭悬浮窗", systemImage: "xmark.circle")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("关闭悬浮窗")
            }
            .controlSize(.regular)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            MarkdownWYSIWYGEditor(
                markdown: $markdown,
                note: note,
                darkMode: colorScheme == .dark,
                chromeBackgroundHex: colorScheme == .dark ? "#292929" : "#FFFFFF",
                accentHex: settings.effectiveAccentHex,
                editable: false,
                onTaskToggle: { _ in },
                onError: { status = $0 }
            )
            .id("\(note.id)-floating-\(colorScheme == .dark ? "dark" : "light")")
        }
        .background(noteBackground)
        .frame(minWidth: 360, minHeight: 420)
        .onAppear { markdown = note.markdown }
        .onChange(of: note.markdown) { markdown = $0 }
    }

    private var noteBackground: Color {
        guard let color = note.color, let nsColor = NSColor(hex: color) else { return Color.clear }
        return Color(nsColor: nsColor).opacity(colorScheme == .dark ? 0.16 : 0.12)
    }

    private func copyMarkdown() {
        clipboardStore.copy(markdown)
        status = "已复制"
    }
}
