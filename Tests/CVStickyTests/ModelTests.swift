import XCTest
@testable import CVSticky

@MainActor
final class ModelTests: XCTestCase {
    func testCaretAnchorKeepsBrowserCoordinatesInFlippedWebView() {
        let bounds = NSRect(x: 8, y: 12, width: 600, height: 800)

        let rect = MarkdownWYSIWYGEditor.caretAnchorRect(
            x: 120,
            y: 240,
            height: 20,
            in: bounds,
            isFlipped: true
        )

        XCTAssertEqual(rect, NSRect(x: 128, y: 252, width: 1, height: 20))
    }

    func testCaretAnchorConvertsBrowserCoordinatesForNonFlippedView() {
        let bounds = NSRect(x: 8, y: 12, width: 600, height: 800)

        let rect = MarkdownWYSIWYGEditor.caretAnchorRect(
            x: 120,
            y: 240,
            height: 20,
            in: bounds,
            isFlipped: false
        )

        XCTAssertEqual(rect, NSRect(x: 128, y: 552, width: 1, height: 20))
    }

    func testClipboardEntryRoundTripPreservesAllContentTypes() throws {
        let entries = [
            ClipboardEntry(type: .text, text: "hello", sourceApp: "Tests"),
            ClipboardEntry(type: .richText, text: "hello", html: "<b>hello</b>", sourceApp: "Tests"),
            ClipboardEntry(type: .image, text: "image", imagePath: "/tmp/image.png", sourceApp: "Tests"),
            ClipboardEntry(type: .files, filePaths: ["/tmp/a.txt", "/tmp/b.txt"], sourceApp: "Tests")
        ]
        let data = try JSONEncoder().encode(entries)
        XCTAssertEqual(try JSONDecoder().decode([ClipboardEntry].self, from: data), entries)
    }

    func testFileClipboardEntryCreatesMarkdownLinks() {
        let entry = ClipboardEntry(type: .files, filePaths: ["/tmp/My File.txt"])
        XCTAssertTrue(entry.noteMarkdown.contains("My%20File.txt"))
        XCTAssertTrue(entry.noteMarkdown.contains("[My File.txt]"))
    }

    func testAIActionDecodesOpenAICompatibleShape() throws {
        let data = #"[{"id":"todo","label":"清单","prompt":"整理","title":"任务","content_markdown":"- [ ] 完成"}]"#.data(using: .utf8)!
        let action = try XCTUnwrap(JSONDecoder().decode([AIPinAction].self, from: data).first)
        XCTAssertEqual(action.id, "todo")
        XCTAssertEqual(action.contentMarkdown, "- [ ] 完成")
    }

    func testHotKeyDefaultsToOptionV() {
        let configuration = HotKeyConfiguration()
        XCTAssertEqual(configuration.keyCode, 9)
        XCTAssertEqual(configuration.displayName, "⌥V")
    }

    func testClipboardHistoryKeepsOneHundredUnpinnedInAdditionToPinnedEntries() {
        let pinned = (0..<8).map { index in
            ClipboardEntry(type: .text, text: "pinned-\(index)", isPinned: true)
        }
        let unpinned = (0..<120).map { index in
            ClipboardEntry(type: .text, text: "normal-\(index)")
        }
        let input = Array(zip(pinned, unpinned.prefix(pinned.count))).flatMap { [$0.0, $0.1] }
            + Array(unpinned.dropFirst(pinned.count))

        let retained = ClipboardStore.retainedHistory(from: input)

        XCTAssertEqual(retained.filter(\.isPinned).count, 8)
        XCTAssertEqual(retained.filter { !$0.isPinned }.count, 100)
        XCTAssertTrue(pinned.allSatisfy { retained.contains($0) })
    }

    func testMetadataRoundTripPreservesQuotesBackslashesCommasAndNewlines() throws {
        let fixture = try TemporaryStoreFixture()
        defer { fixture.cleanup() }
        let store = NoteStore(rootURL: fixture.root, legacyRootURL: fixture.legacy)
        let original = try XCTUnwrap(store.create(title: "标题 \"A\"\\路径\n第二行", markdown: "正文"))
        var updated = original
        updated.tags = ["逗号,标签", "引号\"标签", "反斜杠\\标签"]

        XCTAssertTrue(store.save(updated))
        let reloaded = try XCTUnwrap(store.notes.first(where: { $0.id == original.id }))
        XCTAssertEqual(reloaded.title, updated.title)
        XCTAssertEqual(reloaded.tags, updated.tags)
        XCTAssertEqual(reloaded.markdown, "正文")
    }

    func testMigrationCopiesMissingLegacyNotesWhenDestinationAlreadyContainsNotes() throws {
        let fixture = try TemporaryStoreFixture()
        defer { fixture.cleanup() }
        try fixture.writeNote(named: "existing", body: "当前便签", under: fixture.root)
        try fixture.writeNote(named: "legacy-a", body: "旧便签 A", under: fixture.legacy)
        try fixture.writeNote(named: "legacy-b", body: "旧便签 B", under: fixture.legacy)

        let store = NoteStore(rootURL: fixture.root, legacyRootURL: fixture.legacy)

        XCTAssertEqual(Set(store.notes.map(\.id)), ["existing", "legacy-a", "legacy-b"])
        let secondLaunch = NoteStore(rootURL: fixture.root, legacyRootURL: fixture.legacy)
        XCTAssertEqual(Set(secondLaunch.notes.map(\.id)), ["existing", "legacy-a", "legacy-b"])
    }

    func testArchiveValidationRejectsSymbolicLinks() throws {
        let fixture = try TemporaryStoreFixture()
        defer { fixture.cleanup() }
        let archiveRoot = fixture.base.appendingPathComponent("archive", isDirectory: true)
        try FileManager.default.createDirectory(at: archiveRoot, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: archiveRoot.appendingPathComponent("linked-note.md"),
            withDestinationURL: fixture.base.appendingPathComponent("outside.md")
        )

        XCTAssertThrowsError(try NoteStore.validateArchiveTree(at: archiveRoot))
    }

    func testLocalImageLinksWithSpacesAreNormalizedForMarkdownPreview() {
        let markdown = "![截图](img/截图 2023-04-03 11.51.32.png)"

        let normalized = NoteStore.normalizingLocalImageLinks(in: markdown)

        XCTAssertEqual(
            normalized,
            "![截图](img/%E6%88%AA%E5%9B%BE%202023-04-03%2011.51.32.png)"
        )
    }

    func testEditorImageSchemeRoundTripsToPortableMarkdown() {
        let markdown = "![截图](img/example.png)"

        let editorValue = MarkdownWYSIWYGEditor.editorMarkdown(markdown)

        XCTAssertEqual(editorValue, "![截图](cvsticky-img:///img/example.png)")
        XCTAssertEqual(MarkdownWYSIWYGEditor.storedMarkdown(editorValue), markdown)
    }

    func testSavingDataImageMaterializesFileAndReloadableMarkdown() throws {
        let fixture = try TemporaryStoreFixture()
        defer { fixture.cleanup() }
        let store = NoteStore(rootURL: fixture.root, legacyRootURL: fixture.legacy)
        var note = try XCTUnwrap(store.create())
        note.markdown = "![测试图片](data:image/png;base64,aGVsbG8=)"

        XCTAssertTrue(store.save(note))

        let reloaded = try XCTUnwrap(store.notes.first(where: { $0.id == note.id }))
        let match = try XCTUnwrap(
            reloaded.markdown.range(of: #"img/image-[a-f0-9-]+\.png"#, options: .regularExpression)
        )
        let relativePath = String(reloaded.markdown[match])
        let imageURL = reloaded.folderURL.appendingPathComponent(relativePath)
        XCTAssertEqual(try Data(contentsOf: imageURL), Data("hello".utf8))
    }

    func testEmptyTrashRemovesAllDeletedNotesWithoutTouchingActiveNotes() throws {
        let fixture = try TemporaryStoreFixture()
        defer { fixture.cleanup() }
        let store = NoteStore(rootURL: fixture.root, legacyRootURL: fixture.legacy)
        let active = try XCTUnwrap(store.create(title: "保留"))
        let deletedA = try XCTUnwrap(store.create(title: "删除 A"))
        let deletedB = try XCTUnwrap(store.create(title: "删除 B"))
        store.moveToTrash(deletedA)
        store.moveToTrash(deletedB)

        store.emptyTrash()

        XCTAssertEqual(store.deletedNotes.count, 0)
        XCTAssertEqual(store.notes.map(\.id), [active.id])
    }

    func testSavingTaskStatePersistsAndUpdatesOnlyMatchingInMemoryNote() throws {
        let fixture = try TemporaryStoreFixture()
        defer { fixture.cleanup() }
        let store = NoteStore(rootURL: fixture.root, legacyRootURL: fixture.legacy)
        let note = try XCTUnwrap(store.create(title: "Tasks", markdown: "* [ ] One"))
        let untouched = try XCTUnwrap(store.create(title: "Other", markdown: "Original"))
        try "Externally changed".write(
            to: untouched.folderURL.appendingPathComponent("note.md"),
            atomically: true,
            encoding: .utf8
        )

        var updated = note
        updated.markdown = "* [x] One"
        updated.updatedAt = Date(timeIntervalSince1970: note.updatedAt.timeIntervalSince1970 + 1)
        XCTAssertTrue(store.saveTaskState(updated))
        XCTAssertEqual(store.notes.first(where: { $0.id == note.id })?.markdown, "* [x] One")
        XCTAssertEqual(store.notes.first(where: { $0.id == untouched.id })?.markdown, "Original")

        let reloaded = NoteStore(rootURL: fixture.root, legacyRootURL: fixture.legacy)
        XCTAssertEqual(reloaded.notes.first(where: { $0.id == note.id })?.markdown, "* [x] One")
    }
}

private struct TemporaryStoreFixture {
    let base: URL
    let root: URL
    let legacy: URL

    init() throws {
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cvsticky-tests-\(UUID().uuidString)", isDirectory: true)
        base = baseURL
        root = baseURL.appendingPathComponent("root", isDirectory: true)
        legacy = baseURL.appendingPathComponent("legacy", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
    }

    func writeNote(named name: String, body: String, under directory: URL) throws {
        let folder = directory.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try body.write(to: folder.appendingPathComponent("note.md"), atomically: true, encoding: .utf8)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: base)
    }
}
