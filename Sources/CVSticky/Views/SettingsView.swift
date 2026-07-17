import AppKit
import Carbon
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var aiService: AIService
    @Environment(\.presentationMode) private var presentationMode

    @State private var aiDraft = AIConfiguration()
    @State private var status = ""
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("设置").font(.title2.bold())
                Spacer()
                Button("完成") { presentationMode.wrappedValue.dismiss() }
            }
            .padding(18)
            Divider()

            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    tab("外观", symbol: "paintbrush", index: 0)
                    tab("快捷键", symbol: "keyboard", index: 1)
                    tab("AI", symbol: "sparkles", index: 2)
                    tab("数据", symbol: "externaldrive", index: 3)
                }
                .padding(12)
                .frame(width: 145)
                .background(VisualEffectView(material: .sidebar))

                Group {
                    switch selectedTab {
                    case 0: appearancePane
                    case 1: hotKeyPane
                    case 2: aiPane
                    default: dataPane
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(width: 650, height: 460)
        .onAppear { aiDraft = settings.ai }
    }

    private var appearancePane: some View {
        VStack(alignment: .leading, spacing: 20) {
            paneTitle("外观", detail: "macOS 26 及更高版本自动启用 Liquid Glass。")
            Picker("显示模式", selection: $settings.appearance) {
                ForEach(AppearanceMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Text("主题色").font(.headline)
            HStack(spacing: 12) {
                ForEach(["#0A84FF", "#30D158", "#64D2FF", "#BF5AF2", "#FF375F", "#FF9F0A"], id: \.self) { hex in
                    Button(action: { settings.accentHex = hex }) {
                        Circle().fill(Color(nsColor: NSColor(hex: hex)!)).frame(width: 28, height: 28)
                            .overlay(Circle().stroke(settings.accentHex == hex ? Color.primary : Color.clear, lineWidth: 3))
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private var hotKeyPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            paneTitle("全局快捷键", detail: "在任意应用中呼出剪贴板历史浮窗。")
            KeyRecorder(configuration: $settings.hotKey)
                .frame(width: 260, height: 38)
            Text("当前快捷键：\(settings.hotKey.displayName)").foregroundColor(.secondary)
            Text("快捷键保存后立即生效。请至少使用 Command、Option、Control 或 Shift 中的一个修饰键。")
                .font(.caption).foregroundColor(.secondary)
        }
    }

    private var aiPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            paneTitle("AI 整理", detail: "兼容 OpenAI Chat Completions 接口，密钥保存在系统钥匙串。")
            Toggle("启用 AI 整理", isOn: $aiDraft.enabled)
            TextField("Base URL", text: $aiDraft.baseURL)
            SecureField("API Key", text: $aiDraft.apiKey)
            TextField("模型", text: $aiDraft.model)
            HStack {
                Button("保存") { settings.updateAI(aiDraft); status = "AI 设置已保存" }
                Button("测试连接") {
                    Task {
                        do { _ = try await aiService.testConnection(configuration: aiDraft); status = "连接成功" }
                        catch { status = "连接失败：\(error.localizedDescription)" }
                    }
                }
                if !status.isEmpty { Text(status).font(.caption).foregroundColor(.secondary) }
            }
        }
        .textFieldStyle(.roundedBorder)
    }

    private var dataPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            paneTitle("数据", detail: "便签默认保存在 ~/.cvsticky，可使用 ZIP 迁移。")
            HStack {
                Button("导出全部便签…") { exportNotes() }
                Button("导入便签…") { importNotes() }
                Button("在访达中显示") { NSWorkspace.shared.activateFileViewerSelecting([noteStore.rootURL]) }
            }
            if !status.isEmpty { Text(status).foregroundColor(.secondary) }
        }
    }

    private func tab(_ title: String, symbol: String, index: Int) -> some View {
        Button(action: { selectedTab = index; status = "" }) {
            HStack { Image(systemName: symbol).frame(width: 18); Text(title); Spacer() }
                .padding(8)
                .background(selectedTab == index ? Color.accentColor.opacity(0.16) : Color.clear)
                .cornerRadius(8)
        }.buttonStyle(.plain)
    }

    private func paneTitle(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title3.bold())
            Text(detail).foregroundColor(.secondary)
        }
    }

    private func exportNotes() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.zip]
        panel.nameFieldStringValue = "cvsticky-notes-\(Self.dateFormatter.string(from: Date())).zip"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try noteStore.exportNotes(to: url); status = "已导出到 \(url.lastPathComponent)" }
        catch { status = "导出失败：\(error.localizedDescription)" }
    }

    private func importNotes() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { status = "已导入 \(try noteStore.importNotes(from: url)) 条便签" }
        catch { status = "导入失败：\(error.localizedDescription)" }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter(); formatter.dateFormat = "yyyyMMdd-HHmmss"; return formatter
    }()
}

struct KeyRecorder: NSViewRepresentable {
    @Binding var configuration: HotKeyConfiguration

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.onRecord = { configuration = $0 }
        view.configuration = configuration
        return view
    }

    func updateNSView(_ view: RecorderView, context: Context) {
        view.configuration = configuration
        view.onRecord = { configuration = $0 }
        view.needsDisplay = true
    }

    final class RecorderView: NSView {
        var configuration = HotKeyConfiguration()
        var onRecord: ((HotKeyConfiguration) -> Void)?
        override var acceptsFirstResponder: Bool { true }

        override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self); needsDisplay = true }
        override func keyDown(with event: NSEvent) {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            var carbon: UInt32 = 0
            var names: [String] = []
            if flags.contains(.command) { carbon |= UInt32(cmdKey); names.append("⌘") }
            if flags.contains(.option) { carbon |= UInt32(optionKey); names.append("⌥") }
            if flags.contains(.control) { carbon |= UInt32(controlKey); names.append("⌃") }
            if flags.contains(.shift) { carbon |= UInt32(shiftKey); names.append("⇧") }
            guard carbon != 0 else { NSSound.beep(); return }
            let key = event.charactersIgnoringModifiers?.uppercased() ?? "?"
            names.append(key)
            onRecord?(HotKeyConfiguration(keyCode: UInt32(event.keyCode), modifiers: carbon, displayName: names.joined()))
        }

        override func draw(_ dirtyRect: NSRect) {
            NSColor.controlBackgroundColor.setFill(); NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()
            (configuration.displayName as NSString).draw(
                at: NSPoint(x: 12, y: (bounds.height - 17) / 2),
                withAttributes: [.font: NSFont.systemFont(ofSize: 14, weight: .medium), .foregroundColor: NSColor.labelColor]
            )
        }
    }
}
