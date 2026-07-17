import Foundation

@MainActor
final class NoteStore: ObservableObject {
    @Published private(set) var notes: [Note] = []
    @Published private(set) var deletedNotes: [Note] = []

    let rootURL: URL
    private let trashURL: URL

    init() {
        rootURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cvsticky", isDirectory: true)
        trashURL = rootURL.appendingPathComponent("trash", isDirectory: true)
        try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: trashURL, withIntermediateDirectories: true)
        reload()
    }

    func reload() {
        notes = readNotes(in: rootURL, excludingTrash: true)
        deletedNotes = readNotes(in: trashURL, excludingTrash: false)
    }

    @discardableResult
    func create(title: String = "新便签", markdown: String = "") -> Note? {
        let id = UUID().uuidString.lowercased()
        let folder = rootURL.appendingPathComponent(id, isDirectory: true)
        let note = Note(
            id: id,
            title: title,
            markdown: markdown,
            tags: [],
            color: nil,
            folderURL: folder,
            updatedAt: .now
        )
        guard save(note) else { return nil }
        return notes.first(where: { $0.id == id })
    }

    @discardableResult
    func save(_ note: Note) -> Bool {
        do {
            try FileManager.default.createDirectory(
                at: note.folderURL,
                withIntermediateDirectories: true
            )
            let body = note.markdown.trimmingCharacters(in: .whitespacesAndNewlines)
            let metadata = metadataBlock(for: note)
            try (body + metadata).write(
                to: note.folderURL.appendingPathComponent("note.md"),
                atomically: true,
                encoding: .utf8
            )
            reload()
            return true
        } catch {
            return false
        }
    }

    func moveToTrash(_ note: Note) {
        let destination = uniqueDestination(in: trashURL, name: note.id)
        try? FileManager.default.moveItem(at: note.folderURL, to: destination)
        reload()
    }

    func restore(_ note: Note) {
        let destination = uniqueDestination(in: rootURL, name: note.id)
        try? FileManager.default.moveItem(at: note.folderURL, to: destination)
        reload()
    }

    func deletePermanently(_ note: Note) {
        try? FileManager.default.removeItem(at: note.folderURL)
        reload()
    }

    private func readNotes(in directory: URL, excludingTrash: Bool) -> [Note] {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .contentModificationDateKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )) ?? []

        return urls.compactMap { folder in
            if excludingTrash && folder.lastPathComponent == "trash" { return nil }
            guard (try? folder.resourceValues(forKeys: keys).isDirectory) == true else { return nil }
            let file = folder.appendingPathComponent("note.md")
            guard let raw = try? String(contentsOf: file, encoding: .utf8) else { return nil }
            let parsed = parse(raw)
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            return Note(
                id: folder.lastPathComponent,
                title: parsed.title ?? folder.lastPathComponent,
                markdown: parsed.markdown,
                tags: parsed.tags,
                color: parsed.color,
                folderURL: folder,
                updatedAt: modified
            )
        }.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func metadataBlock(for note: Note) -> String {
        let escapedTitle = note.title.replacingOccurrences(of: "\"", with: "\\\"")
        let tags = note.tags.map { "\"\($0.replacingOccurrences(of: "\"", with: "\\\""))\"" }
            .joined(separator: ", ")
        return "\n\n```for-cvsticky\ntitle: \"\(escapedTitle)\"\ncolor: \(note.color ?? "default")\ntags: [\(tags)]\n```\n"
    }

    private func parse(_ raw: String) -> (markdown: String, title: String?, color: String?, tags: [String]) {
        let markers = ["```for-cvsticky", "```for-clipboard"]
        guard let markerRange = markers.compactMap({ raw.range(of: $0, options: .backwards) }).max(by: {
            $0.lowerBound < $1.lowerBound
        }) else {
            return (raw.trimmingCharacters(in: .whitespacesAndNewlines), nil, nil, [])
        }
        let markdown = String(raw[..<markerRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let remainder = raw[markerRange.upperBound...]
        guard let closing = remainder.range(of: "```") else { return (raw, nil, nil, []) }
        let lines = remainder[..<closing.lowerBound].split(separator: "\n")
        var title: String?
        var color: String?
        var tags: [String] = []
        for line in lines {
            let value = line.trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("title:") {
                title = String(value.dropFirst(6)).trimmingCharacters(in: CharacterSet(charactersIn: " \"") )
            } else if value.hasPrefix("color:") {
                let candidate = String(value.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                color = candidate == "default" ? nil : candidate
            } else if value.hasPrefix("tags:") {
                tags = String(value.dropFirst(5))
                    .trimmingCharacters(in: CharacterSet(charactersIn: " []"))
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " \"'")) }
                    .filter { !$0.isEmpty }
            }
        }
        return (markdown, title, color, tags)
    }

    private func uniqueDestination(in directory: URL, name: String) -> URL {
        let initial = directory.appendingPathComponent(name, isDirectory: true)
        guard FileManager.default.fileExists(atPath: initial.path) else { return initial }
        return directory.appendingPathComponent("\(name)-\(UUID().uuidString.lowercased())", isDirectory: true)
    }
}
