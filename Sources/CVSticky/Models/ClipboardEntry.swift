import Foundation

struct ClipboardEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let text: String
    let createdAt: Date
    var isPinned: Bool

    init(id: UUID = UUID(), text: String, createdAt: Date = .now, isPinned: Bool = false) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.isPinned = isPinned
    }
}
