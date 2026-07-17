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
