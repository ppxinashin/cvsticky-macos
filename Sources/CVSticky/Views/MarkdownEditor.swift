import AppKit
import SwiftUI

@MainActor
final class MarkdownEditorBridge: ObservableObject {
    weak var textView: NSTextView?

    func insert(_ text: String) {
        guard let textView else { return }
        textView.insertText(text, replacementRange: textView.selectedRange())
        textView.didChangeText()
    }

    func wrap(_ prefix: String, suffix: String? = nil) {
        guard let textView else { return }
        let range = textView.selectedRange()
        let selected = (textView.string as NSString).substring(with: range)
        let closing = suffix ?? prefix
        textView.insertText(prefix + selected + closing, replacementRange: range)
        textView.didChangeText()
        if selected.isEmpty {
            textView.setSelectedRange(NSRange(location: range.location + prefix.utf16.count, length: 0))
        }
    }

    func heading(_ level: Int) {
        transformSelectedLines { line in
            let stripped = line.replacingOccurrences(of: #"^#{1,6}\s+"#, with: "", options: .regularExpression)
            return String(repeating: "#", count: level) + " " + stripped
        }
    }

    func linePrefix(_ prefix: String) {
        transformSelectedLines { prefix + $0 }
    }

    private func transformSelectedLines(_ transform: (String) -> String) {
        guard let textView else { return }
        let ns = textView.string as NSString
        let range = ns.lineRange(for: textView.selectedRange())
        let transformed = ns.substring(with: range)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { transform(String($0)) }
            .joined(separator: "\n")
        textView.insertText(transformed, replacementRange: range)
        textView.didChangeText()
    }
}

struct MarkdownTextEditor: NSViewRepresentable {
    @Binding var text: String
    let bridge: MarkdownEditorBridge

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false

        let editor = NSTextView()
        editor.isRichText = false
        editor.allowsUndo = true
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        editor.textContainerInset = NSSize(width: 18, height: 18)
        editor.backgroundColor = .clear
        editor.delegate = context.coordinator
        editor.string = text
        editor.autoresizingMask = [.width]
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.textContainer?.widthTracksTextView = true
        scroll.documentView = editor
        bridge.textView = editor
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let editor = scroll.documentView as? NSTextView else { return }
        if editor.string != text { editor.string = text }
        if bridge.textView !== editor { bridge.textView = editor }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        init(text: Binding<String>) { _text = text }
        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            text = editor.string
        }
    }
}
