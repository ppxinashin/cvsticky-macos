import Foundation

struct Note: Identifiable, Hashable, Sendable {
    let id: String
    var title: String
    var markdown: String
    var tags: [String]
    var color: String?
    let folderURL: URL
    var updatedAt: Date
}
