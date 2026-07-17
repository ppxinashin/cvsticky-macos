import AppKit
import Carbon
import Foundation

enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
}

struct AIConfiguration: Codable, Equatable {
    var enabled = false
    var baseURL = "https://api.openai.com/v1"
    var model = "gpt-4o-mini"
    var apiKey = ""
}

enum AITransformKind: String, CaseIterable, Identifiable {
    case smart
    case structure
    case summary
    case tasks
    case polish
    case translate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smart: return "智能整理"
        case .structure: return "结构化"
        case .summary: return "摘要"
        case .tasks: return "任务清单"
        case .polish: return "优化表达"
        case .translate: return "翻译"
        }
    }

    var symbol: String {
        switch self {
        case .smart: return "wand.and.sparkles"
        case .structure: return "list.bullet.indent"
        case .summary: return "text.quote"
        case .tasks: return "checklist"
        case .polish: return "text.badge.checkmark"
        case .translate: return "character.book.closed"
        }
    }

    var instruction: String {
        switch self {
        case .smart: return "理解内容后给出自然、实用且差异明显的整理方案"
        case .structure: return "按主题和层级重组内容，保留重要细节"
        case .summary: return "提炼重点，生成可快速阅读的摘要"
        case .tasks: return "提取可执行事项，整理为 Markdown 任务清单"
        case .polish: return "不改变事实，改善表达、语气与可读性"
        case .translate: return "完整翻译内容，保留原有 Markdown 结构和专有名词"
        }
    }
}

struct AIPinAction: Identifiable, Codable, Hashable {
    let id: String
    let label: String
    let prompt: String
    let title: String
    let contentMarkdown: String

    enum CodingKeys: String, CodingKey {
        case id, label, prompt, title
        case contentMarkdown = "content_markdown"
    }
}

struct HotKeyConfiguration: Codable, Equatable {
    var keyCode: UInt32 = 9 // V
    var modifiers: UInt32 = UInt32(optionKey)
    var displayName = "⌥V"
}
