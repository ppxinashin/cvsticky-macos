import AppKit
import Foundation

enum ClipboardContentType: String, Codable, CaseIterable, Sendable {
    case text
    case richText
    case image
    case files

    var title: String {
        switch self {
        case .text: return "文本"
        case .richText: return "富文本"
        case .image: return "图片"
        case .files: return "文件"
        }
    }

    var symbol: String {
        switch self {
        case .text: return "text.alignleft"
        case .richText: return "doc.richtext"
        case .image: return "photo"
        case .files: return "doc.on.doc"
        }
    }
}

struct ClipboardEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let type: ClipboardContentType
    let text: String?
    let html: String?
    let imagePath: String?
    let filePaths: [String]
    let sourceApp: String
    let createdAt: Date
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        type: ClipboardContentType = .text,
        text: String? = nil,
        html: String? = nil,
        imagePath: String? = nil,
        filePaths: [String] = [],
        sourceApp: String = "未知来源",
        createdAt: Date = .now,
        isPinned: Bool = false
    ) {
        self.id = id
        self.type = type
        self.text = text
        self.html = html
        self.imagePath = imagePath
        self.filePaths = filePaths
        self.sourceApp = sourceApp
        self.createdAt = createdAt
        self.isPinned = isPinned
    }

    var displayText: String {
        switch type {
        case .image: return text?.nonEmpty ?? "图片"
        case .files: return filePaths.map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: "、")
        case .text, .richText: return text?.nonEmpty ?? "空内容"
        }
    }

    var noteMarkdown: String {
        switch type {
        case .image:
            guard let imagePath else { return displayText }
            return "![图片](\(URL(fileURLWithPath: imagePath).absoluteString))"
        case .files:
            return filePaths.map {
                let url = URL(fileURLWithPath: $0)
                return "[\(url.lastPathComponent)](\(url.absoluteString))"
            }.joined(separator: "\n")
        case .text, .richText:
            return text ?? ""
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, text, html, imagePath, filePaths, sourceApp, createdAt, isPinned
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        type = try values.decodeIfPresent(ClipboardContentType.self, forKey: .type) ?? .text
        text = try values.decodeIfPresent(String.self, forKey: .text)
        html = try values.decodeIfPresent(String.self, forKey: .html)
        imagePath = try values.decodeIfPresent(String.self, forKey: .imagePath)
        filePaths = try values.decodeIfPresent([String].self, forKey: .filePaths) ?? []
        sourceApp = try values.decodeIfPresent(String.self, forKey: .sourceApp) ?? "未知来源"
        createdAt = try values.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        isPinned = try values.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }
}

extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
