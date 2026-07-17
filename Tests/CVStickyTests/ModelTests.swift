import XCTest
@testable import CVSticky

final class ModelTests: XCTestCase {
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
}
