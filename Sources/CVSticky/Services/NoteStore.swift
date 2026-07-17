import AppKit
import Foundation

@MainActor
final class NoteStore: ObservableObject {
    @Published private(set) var notes: [Note] = []
    @Published private(set) var deletedNotes: [Note] = []
    @Published var lastError: String?

    let rootURL: URL
    private let trashURL: URL

    init() {
        rootURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cvsticky", isDirectory: true)
        trashURL = rootURL.appendingPathComponent("trash", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: trashURL, withIntermediateDirectories: true)
        } catch {
            lastError = error.localizedDescription
        }
        migrateLegacyRootIfNeeded()
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
        let now = Date()
        let note = Note(
            id: id,
            title: title,
            markdown: markdown,
            tags: [],
            color: nil,
            folderURL: folder,
            createdAt: now,
            updatedAt: now
        )
        guard save(note) else { return nil }
        return notes.first(where: { $0.id == id })
    }

    @discardableResult
    func create(from entry: ClipboardEntry, title: String? = nil, markdown: String? = nil) -> Note? {
        let proposed = title?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? String(entry.displayText.prefix(24))
        let body: String
        if entry.type == .image, let path = entry.imagePath {
            let id = UUID().uuidString.lowercased()
            let folder = rootURL.appendingPathComponent(id, isDirectory: true)
            let imageFolder = folder.appendingPathComponent("img", isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: imageFolder, withIntermediateDirectories: true)
                let source = URL(fileURLWithPath: path)
                let name = "pinned-\(UUID().uuidString.lowercased()).\(source.pathExtension.nonEmpty ?? "png")"
                try FileManager.default.copyItem(at: source, to: imageFolder.appendingPathComponent(name))
                let now = Date()
                let note = Note(
                    id: id,
                    title: proposed.nonEmpty ?? "图片便签",
                    markdown: markdown ?? "![图片](img/\(name))",
                    tags: [],
                    color: nil,
                    folderURL: folder,
                    createdAt: now,
                    updatedAt: now
                )
                guard save(note) else { return nil }
                return notes.first(where: { $0.id == id })
            } catch {
                lastError = error.localizedDescription
                return nil
            }
        } else {
            body = markdown ?? entry.noteMarkdown
        }
        return create(title: proposed.nonEmpty ?? "剪贴便签", markdown: body)
    }

    @discardableResult
    func save(_ note: Note) -> Bool {
        do {
            try FileManager.default.createDirectory(at: note.folderURL, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(
                at: note.folderURL.appendingPathComponent("img", isDirectory: true),
                withIntermediateDirectories: true
            )
            let body = try materializeDataImages(note.markdown, in: note.folderURL)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            try (body + metadataBlock(for: note)).write(
                to: note.folderURL.appendingPathComponent("note.md"),
                atomically: true,
                encoding: .utf8
            )
            reload()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func addImage(_ source: URL, to note: Note) throws -> String {
        let imageFolder = note.folderURL.appendingPathComponent("img", isDirectory: true)
        try FileManager.default.createDirectory(at: imageFolder, withIntermediateDirectories: true)
        let stem = source.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "/", with: "-")
        let name = "\(stem)-\(UUID().uuidString.lowercased()).\(source.pathExtension.nonEmpty ?? "png")"
        try FileManager.default.copyItem(at: source, to: imageFolder.appendingPathComponent(name))
        return "img/\(name)"
    }

    func deleteImage(markdownPath: String, from note: Note) throws {
        let clean = markdownPath.removingPercentEncoding ?? markdownPath
        guard clean.hasPrefix("img/"), !clean.contains("..") else {
            throw StoreError.invalidImagePath
        }
        let imageRoot = note.folderURL.appendingPathComponent("img", isDirectory: true).standardizedFileURL
        let target = note.folderURL.appendingPathComponent(clean).standardizedFileURL
        guard target.path.hasPrefix(imageRoot.path) else { throw StoreError.invalidImagePath }
        if FileManager.default.fileExists(atPath: target.path) {
            try FileManager.default.removeItem(at: target)
        }
    }

    func moveToTrash(_ note: Note) {
        do {
            try FileManager.default.moveItem(
                at: note.folderURL,
                to: uniqueDestination(in: trashURL, name: note.id)
            )
            reload()
        } catch { lastError = error.localizedDescription }
    }

    func restore(_ note: Note) {
        do {
            try FileManager.default.moveItem(
                at: note.folderURL,
                to: uniqueDestination(in: rootURL, name: note.id)
            )
            reload()
        } catch { lastError = error.localizedDescription }
    }

    func deletePermanently(_ note: Note) {
        do {
            try FileManager.default.removeItem(at: note.folderURL)
            reload()
        } catch { lastError = error.localizedDescription }
    }

    func exportNotes(_ selected: [Note]? = nil, to destination: URL) throws {
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("cvsticky-export-\(UUID().uuidString)", isDirectory: true)
        let notesFolder = staging.appendingPathComponent("notes", isDirectory: true)
        try FileManager.default.createDirectory(at: notesFolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }
        for note in selected ?? notes {
            try FileManager.default.copyItem(
                at: note.folderURL,
                to: notesFolder.appendingPathComponent(note.id, isDirectory: true)
            )
        }
        try runDitto(arguments: ["-c", "-k", "--sequesterRsrc", "--keepParent", notesFolder.path, destination.path])
    }

    @discardableResult
    func importNotes(from archive: URL) throws -> Int {
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("cvsticky-import-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }
        try runDitto(arguments: ["-x", "-k", archive.path, staging.path])
        let candidateRoots = [staging.appendingPathComponent("notes"), staging]
        var imported = 0
        for candidateRoot in candidateRoots where FileManager.default.fileExists(atPath: candidateRoot.path) {
            let folders = (try? FileManager.default.contentsOfDirectory(
                at: candidateRoot,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            for folder in folders where FileManager.default.fileExists(
                atPath: folder.appendingPathComponent("note.md").path
            ) {
                try FileManager.default.copyItem(
                    at: folder,
                    to: uniqueDestination(in: rootURL, name: folder.lastPathComponent)
                )
                imported += 1
            }
            if imported > 0 { break }
        }
        reload()
        return imported
    }

    private func readNotes(in directory: URL, excludingTrash: Bool) -> [Note] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .creationDateKey, .contentModificationDateKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )) ?? []

        return urls.compactMap { folder in
            if excludingTrash && folder.lastPathComponent == "trash" { return nil }
            guard (try? folder.resourceValues(forKeys: Set(keys)).isDirectory) == true else { return nil }
            let file = folder.appendingPathComponent("note.md")
            guard let raw = try? String(contentsOf: file, encoding: .utf8) else { return nil }
            let parsed = parse(raw)
            let values = try? file.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
            let modified = values?.contentModificationDate ?? .distantPast
            return Note(
                id: folder.lastPathComponent,
                title: parsed.title ?? folder.lastPathComponent,
                markdown: parsed.markdown,
                tags: parsed.tags,
                color: parsed.color,
                folderURL: folder,
                createdAt: values?.creationDate ?? modified,
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
                title = String(value.dropFirst(6)).trimmingCharacters(in: CharacterSet(charactersIn: " \""))
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

    private func materializeDataImages(_ markdown: String, in folder: URL) throws -> String {
        let pattern = #"data:image/([A-Za-z0-9.+-]+);base64,([A-Za-z0-9+/=]+)"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(markdown.startIndex..., in: markdown)
        var result = markdown
        for match in regex.matches(in: markdown, range: range).reversed() {
            guard let mimeRange = Range(match.range(at: 1), in: markdown),
                  let dataRange = Range(match.range(at: 2), in: markdown),
                  let fullRange = Range(match.range(at: 0), in: result),
                  let data = Data(base64Encoded: String(markdown[dataRange])) else { continue }
            let ext = String(markdown[mimeRange]).replacingOccurrences(of: "jpeg", with: "jpg")
            let imageFolder = folder.appendingPathComponent("img", isDirectory: true)
            try FileManager.default.createDirectory(at: imageFolder, withIntermediateDirectories: true)
            let name = "image-\(UUID().uuidString.lowercased()).\(ext)"
            try data.write(to: imageFolder.appendingPathComponent(name), options: .atomic)
            result.replaceSubrange(fullRange, with: "img/\(name)")
        }
        return result
    }

    private func uniqueDestination(in directory: URL, name: String) -> URL {
        let initial = directory.appendingPathComponent(name, isDirectory: true)
        guard FileManager.default.fileExists(atPath: initial.path) else { return initial }
        return directory.appendingPathComponent("\(name)-\(UUID().uuidString.lowercased())", isDirectory: true)
    }

    private func migrateLegacyRootIfNeeded() {
        let legacy = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".clipboard", isDirectory: true)
        let alreadyHasNotes = ((try? FileManager.default.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []).contains { folder in
            FileManager.default.fileExists(atPath: folder.appendingPathComponent("note.md").path)
        }
        guard FileManager.default.fileExists(atPath: legacy.path), !alreadyHasNotes else { return }
        let folders = (try? FileManager.default.contentsOfDirectory(
            at: legacy,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        for folder in folders where FileManager.default.fileExists(atPath: folder.appendingPathComponent("note.md").path) {
            try? FileManager.default.copyItem(
                at: folder,
                to: uniqueDestination(in: rootURL, name: folder.lastPathComponent)
            )
        }
    }

    private func runDitto(arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 { throw StoreError.archiveFailed }
    }
}

enum StoreError: LocalizedError {
    case invalidImagePath
    case archiveFailed

    var errorDescription: String? {
        switch self {
        case .invalidImagePath: return "图片路径不合法"
        case .archiveFailed: return "便签归档操作失败"
        }
    }
}
