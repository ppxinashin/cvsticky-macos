import AppKit
import Foundation

@MainActor
final class NoteStore: ObservableObject {
    @Published private(set) var notes: [Note] = []
    @Published private(set) var deletedNotes: [Note] = []
    @Published var lastError: String?

    let rootURL: URL
    private let trashURL: URL
    private let legacyRootURL: URL

    init(rootURL: URL? = nil, legacyRootURL: URL? = nil) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.rootURL = rootURL ?? home.appendingPathComponent(".cvsticky", isDirectory: true)
        self.legacyRootURL = legacyRootURL ?? home.appendingPathComponent(".clipboard", isDirectory: true)
        trashURL = self.rootURL.appendingPathComponent("trash", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: self.rootURL, withIntermediateDirectories: true)
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

    /// Persists an interactive task-list change without reloading the complete
    /// note collection. Reloading here steals the first subsequent WebView
    /// click, while leaving `notes` untouched makes the checked state disappear
    /// as soon as the user switches notes. Replace only the matching value so
    /// the detail view and the file on disk stay in sync without rebuilding the
    /// collection from disk.
    @discardableResult
    func saveTaskState(_ note: Note) -> Bool {
        do {
            try FileManager.default.createDirectory(at: note.folderURL, withIntermediateDirectories: true)
            let body = note.markdown.trimmingCharacters(in: .whitespacesAndNewlines)
            try (body + metadataBlock(for: note)).write(
                to: note.folderURL.appendingPathComponent("note.md"),
                atomically: true,
                encoding: .utf8
            )
            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                notes[index] = note
            }
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func addImage(_ source: URL, to note: Note) throws -> String {
        let imageFolder = note.folderURL.appendingPathComponent("img", isDirectory: true)
        try FileManager.default.createDirectory(at: imageFolder, withIntermediateDirectories: true)
        let ext = source.pathExtension
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
            .nonEmpty ?? "png"
        let name = "image-\(UUID().uuidString.lowercased()).\(ext)"
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

    func emptyTrash() {
        do {
            let items = try FileManager.default.contentsOfDirectory(
                at: trashURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            for item in items {
                try FileManager.default.removeItem(at: item)
            }
            reload()
        } catch {
            lastError = error.localizedDescription
            reload()
        }
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
        try Self.validateArchiveTree(at: staging)
        let candidateRoots = [staging.appendingPathComponent("notes"), staging]
        var imported = 0
        for candidateRoot in candidateRoots where FileManager.default.fileExists(atPath: candidateRoot.path) {
            let folders = (try? FileManager.default.contentsOfDirectory(
                at: candidateRoot,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            for folder in folders {
                let values = try folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                guard values.isDirectory == true, values.isSymbolicLink != true else { continue }
                let noteFile = folder.appendingPathComponent("note.md")
                let noteValues = try? noteFile.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard noteValues?.isRegularFile == true, noteValues?.isSymbolicLink != true else { continue }
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
                markdown: Self.normalizingLocalImageLinks(in: parsed.markdown),
                tags: parsed.tags,
                color: parsed.color,
                folderURL: folder,
                createdAt: values?.creationDate ?? modified,
                updatedAt: modified
            )
        }.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func metadataBlock(for note: Note) -> String {
        let metadata = StoredMetadata(title: note.title, color: note.color, tags: note.tags)
        let encodedMetadata = (try? JSONEncoder().encode(metadata).base64EncodedString()) ?? ""
        let escapedTitle = Self.escapeMetadataValue(note.title)
        let tags = note.tags.map { "\"\(Self.escapeMetadataValue($0))\"" }
            .joined(separator: ", ")
        return "\n\n```for-cvsticky\nmetadata: \(encodedMetadata)\ntitle: \"\(escapedTitle)\"\ncolor: \(note.color ?? "default")\ntags: [\(tags)]\n```\n"
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
            if value.hasPrefix("metadata:") {
                let encoded = String(value.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                if let data = Data(base64Encoded: encoded),
                   let metadata = try? JSONDecoder().decode(StoredMetadata.self, from: data) {
                    return (markdown, metadata.title, metadata.color, metadata.tags)
                }
            } else if value.hasPrefix("title:") {
                let rawTitle = String(value.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                title = Self.unescapeMetadataValue(Self.removingOuterQuotes(rawTitle))
            } else if value.hasPrefix("color:") {
                let candidate = String(value.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                color = candidate == "default" ? nil : candidate
            } else if value.hasPrefix("tags:") {
                tags = Self.parseLegacyTags(String(value.dropFirst(5)))
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
        guard FileManager.default.fileExists(atPath: legacyRootURL.path) else { return }
        let folders = (try? FileManager.default.contentsOfDirectory(
            at: legacyRootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        for folder in folders where FileManager.default.fileExists(atPath: folder.appendingPathComponent("note.md").path) {
            let destination = rootURL.appendingPathComponent(folder.lastPathComponent, isDirectory: true)
            guard !FileManager.default.fileExists(atPath: destination.appendingPathComponent("note.md").path) else {
                continue
            }
            do {
                try FileManager.default.copyItem(
                    at: folder,
                    to: FileManager.default.fileExists(atPath: destination.path)
                        ? uniqueDestination(in: rootURL, name: folder.lastPathComponent)
                        : destination
                )
            } catch {
                lastError = "迁移便签 \(folder.lastPathComponent) 失败：\(error.localizedDescription)"
            }
        }
    }

    static func validateArchiveTree(at root: URL) throws {
        let keys: [URLResourceKey] = [.isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: []
        ) else { throw StoreError.unsafeArchive }

        var itemCount = 0
        var totalBytes: Int64 = 0
        for case let url as URL in enumerator {
            itemCount += 1
            guard itemCount <= 10_000 else { throw StoreError.archiveTooLarge }
            let values = try url.resourceValues(forKeys: Set(keys))
            guard values.isSymbolicLink != true else { throw StoreError.unsafeArchive }
            if values.isRegularFile == true {
                totalBytes += Int64(values.fileSize ?? 0)
                guard totalBytes <= 512 * 1_024 * 1_024 else { throw StoreError.archiveTooLarge }
            }
        }
    }

    static func normalizingLocalImageLinks(in markdown: String) -> String {
        let pattern = #"(!\[[^\]]*\]\()((?:\.?/)?img/[^)\n]+)(\))"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return markdown }
        var result = markdown
        let originalRange = NSRange(markdown.startIndex..., in: markdown)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~/"))
        for match in regex.matches(in: markdown, range: originalRange).reversed() {
            guard let originalPathRange = Range(match.range(at: 2), in: markdown),
                  let resultPathRange = Range(match.range(at: 2), in: result) else { continue }
            let originalPath = String(markdown[originalPathRange])
            let decodedPath = originalPath.removingPercentEncoding ?? originalPath
            guard let encodedPath = decodedPath.addingPercentEncoding(withAllowedCharacters: allowed) else { continue }
            result.replaceSubrange(resultPathRange, with: encodedPath)
        }
        return result
    }

    private static func escapeMetadataValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }

    private static func unescapeMetadataValue(_ value: String) -> String {
        var result = ""
        var escaping = false
        for character in value {
            if escaping {
                switch character {
                case "n": result.append("\n")
                case "r": result.append("\r")
                default: result.append(character)
                }
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else {
                result.append(character)
            }
        }
        if escaping { result.append("\\") }
        return result
    }

    private static func removingOuterQuotes(_ value: String) -> String {
        guard value.count >= 2,
              let first = value.first,
              let last = value.last,
              (first == "\"" && last == "\"") || (first == "'" && last == "'")
        else { return value }
        return String(value.dropFirst().dropLast())
    }

    private static func parseLegacyTags(_ value: String) -> [String] {
        let content = value.trimmingCharacters(in: CharacterSet(charactersIn: " []"))
        var tags: [String] = []
        var current = ""
        var quote: Character?
        var escaping = false
        for character in content {
            if escaping {
                current.append("\\")
                current.append(character)
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else if let activeQuote = quote {
                if character == activeQuote { quote = nil } else { current.append(character) }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character == "," {
                let tag = unescapeMetadataValue(current.trimmingCharacters(in: .whitespaces))
                if !tag.isEmpty { tags.append(tag) }
                current = ""
            } else {
                current.append(character)
            }
        }
        if escaping { current.append("\\") }
        let tag = unescapeMetadataValue(current.trimmingCharacters(in: .whitespaces))
        if !tag.isEmpty { tags.append(tag) }
        return tags
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
    case unsafeArchive
    case archiveTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidImagePath: return "图片路径不合法"
        case .archiveFailed: return "便签归档操作失败"
        case .unsafeArchive: return "导入包包含不安全的符号链接"
        case .archiveTooLarge: return "导入包内容过多或体积过大"
        }
    }
}

private struct StoredMetadata: Codable {
    let title: String
    let color: String?
    let tags: [String]
}
