import AppKit
import Foundation

@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var entries: [ClipboardEntry] = []
    @Published var searchText = ""

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?
    private let historyURL: URL
    private let assetsURL: URL

    init() {
        lastChangeCount = pasteboard.changeCount
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!.appendingPathComponent("CVSticky", isDirectory: true)
        assetsURL = support.appendingPathComponent("clipboard-assets", isDirectory: true)
        historyURL = support.appendingPathComponent("clipboard-history.json")
        try? FileManager.default.createDirectory(at: assetsURL, withIntermediateDirectories: true)
        load()
    }

    var filteredEntries: [ClipboardEntry] {
        guard !searchText.isEmpty else { return entries }
        return entries.filter {
            $0.displayText.localizedCaseInsensitiveContains(searchText)
                || $0.sourceApp.localizedCaseInsensitiveContains(searchText)
                || $0.type.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func copy(_ entry: ClipboardEntry) {
        pasteboard.clearContents()
        switch entry.type {
        case .image:
            if let path = entry.imagePath, let image = NSImage(contentsOfFile: path) {
                pasteboard.writeObjects([image])
            }
        case .files:
            pasteboard.writeObjects(entry.filePaths.map { URL(fileURLWithPath: $0) as NSURL })
        case .richText:
            if let html = entry.html {
                pasteboard.setString(html, forType: .html)
            }
            pasteboard.setString(entry.text ?? "", forType: .string)
        case .text:
            pasteboard.setString(entry.text ?? "", forType: .string)
        }
        lastChangeCount = pasteboard.changeCount
    }

    func copy(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        lastChangeCount = pasteboard.changeCount
    }

    func markPinned(_ id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].isPinned = true
        save()
    }

    func delete(_ entry: ClipboardEntry) {
        entries.removeAll { $0.id == entry.id }
        removeAssetIfNeeded(entry)
        save()
    }

    func clearUnpinned() {
        let removed = entries.filter { !$0.isPinned }
        entries.removeAll { !$0.isPinned }
        removed.forEach(removeAssetIfNeeded)
        save()
    }

    private func poll() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        guard let entry = captureCurrentPasteboard() else { return }
        guard !isDuplicateOfMostRecent(entry) else { return }
        entries.insert(entry, at: 0)
        trimHistory()
        save()
    }

    private func captureCurrentPasteboard() -> ClipboardEntry? {
        let source = NSWorkspace.shared.frontmostApplication?.localizedName ?? "未知来源"

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], !urls.isEmpty {
            return ClipboardEntry(type: .files, filePaths: urls.map(\.path), sourceApp: source)
        }

        if let image = NSImage(pasteboard: pasteboard),
           let data = image.pngData {
            let file = assetsURL.appendingPathComponent("clip-\(UUID().uuidString.lowercased()).png")
            do {
                try data.write(to: file, options: .atomic)
                return ClipboardEntry(type: .image, imagePath: file.path, sourceApp: source)
            } catch {
                return nil
            }
        }

        let text = pasteboard.string(forType: .string)
        let html = pasteboard.string(forType: .html)
        if let text, !text.isEmpty {
            return ClipboardEntry(
                type: html == nil ? .text : .richText,
                text: text,
                html: html,
                sourceApp: source
            )
        }
        return nil
    }

    private func isDuplicateOfMostRecent(_ entry: ClipboardEntry) -> Bool {
        guard let latest = entries.first else { return false }
        switch entry.type {
        case .image:
            guard latest.type == .image,
                  let left = latest.imagePath.flatMap({ try? Data(contentsOf: URL(fileURLWithPath: $0)) }),
                  let right = entry.imagePath.flatMap({ try? Data(contentsOf: URL(fileURLWithPath: $0)) })
            else { return false }
            if left == right {
                removeAssetIfNeeded(entry)
                return true
            }
            return false
        case .files: return latest.type == .files && latest.filePaths == entry.filePaths
        case .text, .richText: return latest.text == entry.text && latest.type == entry.type
        }
    }

    private func trimHistory() {
        let kept = Self.retainedHistory(from: entries)
        let allowed = Set(kept.map(\.id))
        let removed = entries.filter { !allowed.contains($0.id) }
        entries = kept
        removed.forEach(removeAssetIfNeeded)
    }

    static func retainedHistory(from entries: [ClipboardEntry], maxUnpinned: Int = 100) -> [ClipboardEntry] {
        var remainingUnpinned = max(0, maxUnpinned)
        return entries.filter { entry in
            if entry.isPinned { return true }
            guard remainingUnpinned > 0 else { return false }
            remainingUnpinned -= 1
            return true
        }
    }

    private func removeAssetIfNeeded(_ entry: ClipboardEntry) {
        guard let path = entry.imagePath,
              URL(fileURLWithPath: path).deletingLastPathComponent().standardizedFileURL == assetsURL.standardizedFileURL
        else { return }
        try? FileManager.default.removeItem(atPath: path)
    }

    private func load() {
        guard let data = try? Data(contentsOf: historyURL),
              let decoded = try? JSONDecoder().decode([ClipboardEntry].self, from: data)
        else { return }
        entries = decoded.filter { entry in
            entry.imagePath.map { FileManager.default.fileExists(atPath: $0) } ?? true
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: historyURL, options: .atomic)
    }
}

private extension NSImage {
    var pngData: Data? {
        guard let tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation)
        else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
