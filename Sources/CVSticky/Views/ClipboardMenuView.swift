import SwiftUI

struct ClipboardMenuView: View {
    @EnvironmentObject private var clipboardStore: ClipboardStore
    @EnvironmentObject private var noteStore: NoteStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if clipboardStore.entries.isEmpty {
                Text("暂无剪贴记录")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(clipboardStore.entries.prefix(12)) { entry in
                    HStack {
                        Button {
                            clipboardStore.copy(entry)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.text.replacingOccurrences(of: "\n", with: " "))
                                    .lineLimit(2)
                                Text(entry.createdAt, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)

                        Button {
                            if noteStore.create(
                                title: String(entry.text.prefix(20)),
                                markdown: entry.text
                            ) != nil {
                                clipboardStore.markPinned(entry.id)
                            }
                        } label: {
                            Image(systemName: entry.isPinned ? "pin.fill" : "pin")
                        }
                        .buttonStyle(.borderless)
                        .disabled(entry.isPinned)

                        Button(role: .destructive) {
                            clipboardStore.delete(entry)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    Divider()
                }
            }

            HStack {
                Button("打开剪贴笺") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
                }
                Spacer()
                Button("退出") { NSApp.terminate(nil) }
            }
        }
        .padding(12)
        .frame(width: 390)
    }
}
