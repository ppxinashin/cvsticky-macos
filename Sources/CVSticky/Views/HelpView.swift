import AppKit
import SwiftUI

struct HelpView: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                hero
                quickStart
                screenshotSection(
                    title: "认识主窗口",
                    detail: "从左到右依次是筛选边栏、便签列表和内容区。选中项使用主题色，失焦后自动变灰。",
                    resource: "help-main-window",
                    bullets: [
                        "边栏可按全部便签、最近删除、标签和颜色筛选。",
                        "在便签行上向右滑动，可显示悬浮和删除操作。",
                        "选择便签后，可在右侧预览、复制或进入编辑模式。"
                    ]
                )
                screenshotSection(
                    title: "使用剪贴板历史",
                    detail: "按 Option+V 在当前鼠标所在显示器呼出剪贴板窗口。",
                    resource: "help-clipboard",
                    bullets: [
                        "输入关键词筛选，使用 ↑/↓ 选择，按 Return 复制。",
                        "支持文本、富文本、图片和文件，普通记录保留最近 100 条。",
                        "向右滑动记录，可存为便签、进行 AI 整理或删除。"
                    ]
                )
                screenshotSection(
                    title: "编辑与整理便签",
                    detail: "编辑器提供常用 Markdown 排版，同时支持任务列表、表格、公式和 Mermaid。",
                    resource: "help-editor",
                    bullets: [
                        "使用“格式”“列表”“插入”菜单完成结构化编辑。",
                        "便签可设置颜色与标签；保存后写入本地 Markdown 文件。",
                        "正文支持中文输入法、图片粘贴、任务勾选和实时预览。"
                    ]
                )
                shortcutSection
                settingsAndData
            }
            .padding(.horizontal, 38)
            .padding(.top, 34)
            .padding(.bottom, 48)
            .frame(maxWidth: 1040, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(Color(nsColor: settings.accentColor))
        .accentColor(Color(nsColor: settings.accentColor))
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 68, height: 68)
                .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
            VStack(alignment: .leading, spacing: 6) {
                Text("剪贴笺使用手册")
                    .font(.system(size: 30, weight: .bold))
                Text("记录灵感、管理剪贴板，并用 Markdown 整理成可长期保存的便签。")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var quickStart: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("快速开始", symbol: "sparkles")
            HStack(spacing: 12) {
                quickCard(number: "1", title: "复制内容", detail: "正常复制文本、图片或文件")
                quickCard(number: "2", title: "打开历史", detail: "按 Option+V 呼出剪贴板")
                quickCard(number: "3", title: "保存整理", detail: "复制、存为便签或 AI 整理")
            }
        }
    }

    private func quickCard(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.headline)
                .foregroundStyle(Color(nsColor: settings.accentColor))
                .frame(width: 28, height: 28)
                .background(Color(nsColor: settings.accentColor).opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    }

    private func screenshotSection(
        title: String,
        detail: String,
        resource: String,
        bullets: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(title, symbol: "macwindow")
            Text(detail).foregroundStyle(.secondary)
            helpScreenshot(named: resource)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(bullets, id: \.self) { bullet in
                    Label(bullet, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.primary, Color(nsColor: settings.accentColor))
                }
            }
            .font(.callout)
        }
    }

    @ViewBuilder
    private func helpScreenshot(named name: String) -> some View {
        if let image = Self.resourceImage(named: name) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.secondary.opacity(0.22))
                )
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
                .frame(height: 260)
                .overlay {
                    Label("界面截图将在构建文档时生成", systemImage: "photo")
                        .foregroundStyle(.secondary)
                }
        }
    }

    private var shortcutSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("常用快捷键", symbol: "keyboard")
            VStack(spacing: 0) {
                shortcutRow("打开剪贴板历史", keys: "Option+V")
                Divider()
                shortcutRow("新建便签", keys: "⌘N")
                Divider()
                shortcutRow("显示或隐藏边栏", keys: "⌥⌘S")
                Divider()
                shortcutRow("编辑当前便签", keys: "⌘E")
                Divider()
                shortcutRow("保存当前便签", keys: "⌘S")
                Divider()
                shortcutRow("打开设置", keys: "⌘,")
                Divider()
                shortcutRow("打开本帮助", keys: "⌘?")
            }
            .padding(.horizontal, 16)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func shortcutRow(_ action: String, keys: String) -> some View {
        HStack {
            Text(action)
            Spacer()
            Text(keys)
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(.vertical, 10)
    }

    private var settingsAndData: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("主题、数据与隐私", symbol: "hand.raised")
            Text("在“设置”中可选择浅色、深色或跟随系统外观，并选择自定义主题色或跟随 macOS 系统强调色。API Key 保存在系统钥匙串；便签默认保存在 ~/.cvsticky，剪贴板历史保存在用户资料库中。建议定期在“设置 → 数据”导出 ZIP 备份。")
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
    }

    private func sectionTitle(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.title2.weight(.semibold))
    }

    private static func resourceImage(named name: String) -> NSImage? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }
}
