import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WebKit

struct MarkdownWYSIWYGEditor: NSViewRepresentable {
    @Binding var markdown: String
    let note: Note
    let darkMode: Bool
    let chromeBackgroundHex: String
    let editable: Bool
    var onTaskToggle: (String) -> Void
    var onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        let binding = $markdown
        return Coordinator(
            onChange: { binding.wrappedValue = $0 },
            onTaskToggle: onTaskToggle,
            onError: onError
        )
    }

    func makeNSView(context: Context) -> WKWebView {
        context.coordinator.noteID = note.id
        context.coordinator.noteFolderURL = note.folderURL
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(context.coordinator, forURLScheme: "cvsticky-img")
        let controller = configuration.userContentController
        controller.add(context.coordinator, name: "editorChanged")
        controller.add(context.coordinator, name: "editorReady")
        controller.add(context.coordinator, name: "editorError")
        controller.add(context.coordinator, name: "slashMenu")
        controller.add(context.coordinator, name: "taskToggled")
        controller.add(context.coordinator, name: "imageUpload")
        controller.add(context.coordinator, name: "editorContextMenu")
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = FirstClickWKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = webView
        context.coordinator.lastMarkdown = markdown
        context.coordinator.desiredMarkdown = markdown
        context.coordinator.lastChromeBackgroundHex = chromeBackgroundHex
        context.coordinator.desiredEditable = editable
        webView.loadHTMLString(html(), baseURL: note.folderURL)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.desiredMarkdown = markdown
        context.coordinator.desiredEditable = editable
        context.coordinator.applyDesiredEditable(in: webView)
        if chromeBackgroundHex != context.coordinator.lastChromeBackgroundHex {
            context.coordinator.lastChromeBackgroundHex = chromeBackgroundHex
            webView.evaluateJavaScript(
                "document.documentElement.style.setProperty('--editor-chrome-background', '\(chromeBackgroundHex)')"
            )
        }
        context.coordinator.applyDesiredMarkdown(in: webView)
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        let controller = webView.configuration.userContentController
        controller.removeScriptMessageHandler(forName: "editorChanged")
        controller.removeScriptMessageHandler(forName: "editorReady")
        controller.removeScriptMessageHandler(forName: "editorError")
        controller.removeScriptMessageHandler(forName: "slashMenu")
        controller.removeScriptMessageHandler(forName: "taskToggled")
        controller.removeScriptMessageHandler(forName: "imageUpload")
        controller.removeScriptMessageHandler(forName: "editorContextMenu")
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.stopLoading()
    }

    static func caretAnchorRect(
        x: CGFloat,
        y: CGFloat,
        height: CGFloat,
        in bounds: NSRect,
        isFlipped: Bool
    ) -> NSRect {
        let caretHeight = max(1, height)
        let caretY = isFlipped
            ? bounds.minY + y
            : bounds.maxY - y - caretHeight
        return NSRect(
            x: bounds.minX + x,
            y: caretY,
            width: 1,
            height: caretHeight
        )
    }

    private func html() -> String {
        let script = resource("milkdown-editor", extension: "js")
        let stylesheet = resource("milkdown-editor", extension: "css")
        let encoded = Data(Self.editorMarkdown(markdown).utf8).base64EncodedString()
        let background = darkMode ? "#292929" : "#ffffff"
        let foreground = darkMode ? "#f2f2f2" : "#202124"
        let surface = darkMode ? "#333333" : "#f5f5f5"
        let surfaceLow = darkMode ? "#3b3b3b" : "#ebebeb"
        let secondary = darkMode ? "#b7b7b7" : "#666666"
        let outline = darkMode ? "#676767" : "#b8b8b8"
        return """
        <!doctype html>
        <html><head><meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src cvsticky-img: file: data: blob: https: http:; font-src data:; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src 'none'; object-src 'none'; frame-src 'none'">
        <style>
        \(stylesheet)
        :root{color-scheme:\(darkMode ? "dark" : "light");--editor-chrome-background:\(chromeBackgroundHex)}
        html{height:100%;margin:0;background:transparent;color:\(foreground)}
        body{min-height:100%;margin:0;overflow:visible;background:transparent;color:\(foreground);font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text",sans-serif}
        #editor{min-height:100vh}
        .milkdown{
          min-height:100%;background:transparent;color:\(foreground);
          --crepe-color-background:\(background);--crepe-color-on-background:\(foreground);
          --crepe-color-surface:\(surface);--crepe-color-surface-low:\(surfaceLow);
          --crepe-color-on-surface:\(foreground);--crepe-color-on-surface-variant:\(secondary);
          --crepe-color-outline:\(outline);--crepe-color-primary:#0a84ff;
          --crepe-color-secondary:\(surfaceLow);--crepe-color-on-secondary:\(foreground);
          --crepe-color-inverse:\(foreground);--crepe-color-on-inverse:\(background);
          --crepe-color-inline-code:#ff7ab2;--crepe-color-error:#ff453a;
          --crepe-color-hover:\(surfaceLow);--crepe-color-selected:rgba(10,132,255,.22);
          --crepe-color-inline-area:\(surfaceLow);
          --crepe-font-title:-apple-system,BlinkMacSystemFont,"SF Pro Display",sans-serif;
          --crepe-font-default:-apple-system,BlinkMacSystemFont,"SF Pro Text",sans-serif;
          --crepe-font-code:ui-monospace,SFMono-Regular,Menlo,monospace;
          --crepe-shadow-1:0 2px 8px rgba(0,0,0,.18);--crepe-shadow-2:0 6px 18px rgba(0,0,0,.22)
        }
        .milkdown .ProseMirror{box-sizing:border-box;max-width:900px;min-height:100%;margin:0 auto;padding:32px 42px 160px;outline:none;font-size:16px;line-height:1.7}
        .milkdown img{max-width:100%;border-radius:12px}
        .cvsticky-readonly .milkdown .label-wrapper{pointer-events:auto!important;cursor:default!important}
        .cvsticky-readonly .milkdown .label-wrapper .label,
        .cvsticky-readonly .milkdown .label-wrapper .label *{pointer-events:none!important}
        .cvsticky-readonly .milkdown .ProseMirror{caret-color:transparent}
        .milkdown .cvsticky-task-checkbox{appearance:none;-webkit-appearance:none;width:24px;height:32px;margin:0;padding:0;display:block;position:relative;cursor:pointer;border:0;background:transparent}
        .milkdown .cvsticky-task-checkbox::before{content:"";box-sizing:border-box;position:absolute;left:4px;top:8px;width:16px;height:16px;border:1.5px solid \(outline);border-radius:4px;background:transparent}
        .milkdown .cvsticky-task-checkbox[aria-checked="true"]::before{border-color:#0a84ff;background:#0a84ff}
        .milkdown .cvsticky-task-checkbox[aria-checked="true"]::after{content:"";position:absolute;left:8px;top:9px;width:5px;height:9px;border:solid white;border-width:0 2px 2px 0;transform:rotate(45deg)}
        .milkdown .milkdown-list-item-block li .label-wrapper{width:24px;height:32px;flex:0 0 24px;align-items:center;justify-content:center}
        .milkdown .milkdown-list-item-block[data-task-checked="true"] > .list-item > .children > .content-dom > :first-child{text-decoration:line-through;text-decoration-thickness:1px;opacity:.62}
        .cvsticky-readonly .milkdown-code-block.cvsticky-preview-only .cm-editor,
        .cvsticky-readonly .milkdown-code-block.cvsticky-preview-only .tools,
        .cvsticky-readonly .milkdown-code-block.cvsticky-preview-only .language-picker,
        .cvsticky-readonly .milkdown-code-block.cvsticky-preview-only .preview-label,
        .cvsticky-readonly .milkdown-code-block.cvsticky-preview-only .preview-divider{display:none!important}
        .cvsticky-readonly .milkdown-code-block.cvsticky-preview-only{padding:14px 16px}
        </style></head>
        <body>
        <div id="editor"></div>
        <script>
        window.addEventListener('error',event=>{
          const message=String(event.error?.stack||event.message||'');
          // WebKit reports opaque cross-origin failures as exactly "Script error."
          // without an Error object, source file, or location. The editor remains
          // functional in that case, so do not surface the non-actionable false alarm.
          if(!event.error&&(!message||message==='Script error.'))return;
          const location=event.filename?`\n${event.filename}:${event.lineno||0}:${event.colno||0}`:'';
          window.webkit.messageHandlers.editorError.postMessage((message||'编辑器脚本加载失败')+location);
        });
        window.addEventListener('unhandledrejection',event=>{
          const reason=event.reason;
          const message=String(reason?.stack||reason?.message||reason||'编辑器加载失败');
          window.webkit.messageHandlers.editorError.postMessage(message);
        });
        </script>
        <script>\(script)</script>
        <script>
        const initialMarkdown=decodeURIComponent(escape(atob('\(encoded)')));
        window.CVStickyWYSIWYG.create({
          root:document.querySelector('#editor'),
          markdown:initialMarkdown,
          editable:\(editable),
          onChange:value=>window.webkit.messageHandlers.editorChanged.postMessage(value),
          onTaskToggle:value=>window.webkit.messageHandlers.taskToggled.postMessage(value),
          onReady:()=>window.webkit.messageHandlers.editorReady.postMessage(true),
          onError:error=>window.webkit.messageHandlers.editorError.postMessage(error)
        });
        document.addEventListener('contextmenu',event=>{
          if(document.body.classList.contains('cvsticky-readonly'))return;
          event.preventDefault();
          window.webkit.messageHandlers.editorContextMenu.postMessage({x:event.clientX,y:event.clientY});
        });
        </script></body></html>
        """
    }

    private func resource(_ name: String, extension ext: String) -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return text
    }

    static func editorMarkdown(_ markdown: String) -> String {
        markdown
            .replacingOccurrences(of: "](./img/", with: "](cvsticky-img:///img/")
            .replacingOccurrences(of: "](img/", with: "](cvsticky-img:///img/")
    }

    static func storedMarkdown(_ markdown: String) -> String {
        markdown.replacingOccurrences(of: "](cvsticky-img:///img/", with: "](img/")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate, WKURLSchemeHandler, NSPopoverDelegate {
        var lastMarkdown = ""
        var desiredMarkdown = ""
        var lastChromeBackgroundHex = ""
        var lastAppliedEditable: Bool?
        var desiredEditable = false
        var isReady = false
        var noteID = ""
        var noteFolderURL: URL?
        weak var webView: WKWebView?
        private var commandObserver: NSObjectProtocol?
        private var slashPopover: NSPopover?
        private let onChange: (String) -> Void
        private let onTaskToggle: (String) -> Void
        private let onError: (String) -> Void

        init(
            onChange: @escaping (String) -> Void,
            onTaskToggle: @escaping (String) -> Void,
            onError: @escaping (String) -> Void
        ) {
            self.onChange = onChange
            self.onTaskToggle = onTaskToggle
            self.onError = onError
            super.init()
            commandObserver = NotificationCenter.default.addObserver(
                forName: .markdownEditorCommand,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self,
                      self.isReady,
                      self.desiredEditable,
                      let request = notification.object as? MarkdownEditorCommandRequest,
                      (request.noteID == nil || request.noteID == self.noteID),
                      let javascript = self.javascript(for: request) else { return }
                self.webView?.evaluateJavaScript(javascript)
            }
        }

        deinit {
            if let commandObserver {
                NotificationCenter.default.removeObserver(commandObserver)
            }
        }

        private func javascript(for request: MarkdownEditorCommandRequest) -> String? {
            guard let commandData = try? JSONSerialization.data(
                withJSONObject: request.command,
                options: .fragmentsAllowed
            ), let command = String(data: commandData, encoding: .utf8) else { return nil }
            var payload: [String: Int] = [:]
            if let row = request.row { payload["row"] = row }
            if let column = request.column { payload["col"] = column }
            let payloadString: String
            if payload.isEmpty {
                payloadString = "undefined"
            } else if let data = try? JSONSerialization.data(withJSONObject: payload),
                      let json = String(data: data, encoding: .utf8) {
                payloadString = json
            } else {
                return nil
            }
            return "window.__cvstickyPerform(\(command), \(payloadString))"
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "editorChanged":
                guard let value = message.body as? String else { return }
                let storedValue = MarkdownWYSIWYGEditor.storedMarkdown(value)
                lastMarkdown = storedValue
                desiredMarkdown = storedValue
                DispatchQueue.main.async { self.onChange(storedValue) }
            case "editorReady":
                isReady = true
                if let webView = message.webView {
                    applyDesiredEditable(in: webView)
                    applyDesiredMarkdown(in: webView)
                }
            case "editorError":
                DispatchQueue.main.async { self.onError(message.body as? String ?? "编辑器加载失败") }
            case "slashMenu":
                guard desiredEditable,
                      let webView = message.webView,
                      let position = message.body as? [String: Any],
                      let x = position["x"] as? NSNumber,
                      let y = position["y"] as? NSNumber else { return }
                let height = (position["height"] as? NSNumber)?.doubleValue ?? 1
                let action = position["action"] as? String ?? "show"
                DispatchQueue.main.async {
                    let caretRect = MarkdownWYSIWYGEditor.caretAnchorRect(
                        x: CGFloat(x.doubleValue),
                        y: CGFloat(y.doubleValue),
                        height: CGFloat(height),
                        in: webView.bounds,
                        isFlipped: webView.isFlipped
                    )
                    if action == "show" {
                        self.showSlashPopover(relativeTo: caretRect, in: webView)
                    } else {
                        self.repositionSlashPopover(
                            relativeTo: caretRect,
                            in: webView
                        )
                    }
                }
            case "taskToggled":
                guard let value = message.body as? String else { return }
                let storedValue = MarkdownWYSIWYGEditor.storedMarkdown(value)
                lastMarkdown = storedValue
                desiredMarkdown = storedValue
                DispatchQueue.main.async {
                    self.onTaskToggle(storedValue)
                }
            case "imageUpload":
                persistUploadedImage(message.body, in: message.webView)
            case "editorContextMenu":
                guard desiredEditable,
                      let webView = message.webView,
                      let position = message.body as? [String: Any],
                      let x = position["x"] as? NSNumber,
                      let y = position["y"] as? NSNumber else { return }
                DispatchQueue.main.async {
                    let point = NSPoint(
                        x: x.doubleValue,
                        y: webView.isFlipped ? y.doubleValue : webView.bounds.height - y.doubleValue
                    )
                    self.makeEditorContextMenu().popUp(positioning: nil, at: point, in: webView)
                }
            default:
                break
            }
        }

        private func persistUploadedImage(_ body: Any, in webView: WKWebView?) {
            guard let payload = body as? [String: Any],
                  let requestID = payload["id"] as? String,
                  let dataURL = payload["dataURL"] as? String,
                  let comma = dataURL.firstIndex(of: ","),
                  let data = Data(base64Encoded: String(dataURL[dataURL.index(after: comma)...])),
                  let noteFolderURL else { return }

            let header = String(dataURL[..<comma]).lowercased()
            let ext: String
            if header.contains("image/jpeg") { ext = "jpg" }
            else if header.contains("image/gif") { ext = "gif" }
            else if header.contains("image/webp") { ext = "webp" }
            else if header.contains("image/heic") || header.contains("image/heif") { ext = "heic" }
            else { ext = "png" }

            do {
                let imageFolder = noteFolderURL.appendingPathComponent("img", isDirectory: true)
                try FileManager.default.createDirectory(at: imageFolder, withIntermediateDirectories: true)
                let name = "image-\(UUID().uuidString.lowercased()).\(ext)"
                try data.write(to: imageFolder.appendingPathComponent(name), options: .atomic)
                resolveImageUpload(
                    requestID: requestID,
                    path: "cvsticky-img:///img/\(name)",
                    error: nil,
                    in: webView
                )
            } catch {
                resolveImageUpload(requestID: requestID, path: nil, error: error.localizedDescription, in: webView)
            }
        }

        private func resolveImageUpload(requestID: String, path: String?, error: String?, in webView: WKWebView?) {
            let values: [Any] = [requestID, path ?? NSNull(), error ?? NSNull()]
            guard let data = try? JSONSerialization.data(withJSONObject: values),
                  let json = String(data: data, encoding: .utf8) else { return }
            webView?.evaluateJavaScript("window.__cvstickyResolveImageUpload(...\(json))")
        }

        func applyDesiredEditable(in webView: WKWebView) {
            guard isReady, lastAppliedEditable != desiredEditable else { return }
            lastAppliedEditable = desiredEditable
            if !desiredEditable {
                slashPopover?.performClose(nil)
            }
            webView.evaluateJavaScript(
                "window.CVStickyWYSIWYG.setEditable(\(desiredEditable))"
            )
        }

        func applyDesiredMarkdown(in webView: WKWebView) {
            guard isReady, desiredMarkdown != lastMarkdown else { return }
            lastMarkdown = desiredMarkdown
            let editorValue = MarkdownWYSIWYGEditor.editorMarkdown(desiredMarkdown)
            let encoded = Data(editorValue.utf8).base64EncodedString()
            webView.evaluateJavaScript(
                "window.CVStickyWYSIWYG.setMarkdown(decodeURIComponent(escape(atob('\(encoded)'))))"
            )
        }

        func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
            guard let url = urlSchemeTask.request.url,
                  url.scheme == "cvsticky-img",
                  let noteFolderURL else {
                urlSchemeTask.didFailWithError(StoreError.invalidImagePath)
                return
            }
            let relativePath = url.path.removingPercentEncoding?
                .trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? ""
            guard relativePath.hasPrefix("img/"), !relativePath.contains("..") else {
                urlSchemeTask.didFailWithError(StoreError.invalidImagePath)
                return
            }
            let imageRoot = noteFolderURL.appendingPathComponent("img", isDirectory: true).standardizedFileURL
            let fileURL = noteFolderURL.appendingPathComponent(relativePath).standardizedFileURL
            guard fileURL.path.hasPrefix(imageRoot.path),
                  let data = try? Data(contentsOf: fileURL) else {
                urlSchemeTask.didFailWithError(StoreError.invalidImagePath)
                return
            }
            let mimeType = UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType
                ?? "application/octet-stream"
            let response = URLResponse(
                url: url,
                mimeType: mimeType,
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        }

        func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

        private func showSlashPopover(relativeTo caretRect: NSRect, in webView: WKWebView) {
            self.webView = webView
            let popover = slashPopover ?? makeSlashPopover()
            slashPopover = popover
            popover.show(relativeTo: caretRect, of: webView, preferredEdge: .minY)
        }

        private func repositionSlashPopover(relativeTo caretRect: NSRect, in webView: WKWebView) {
            guard let slashPopover, slashPopover.isShown else { return }
            slashPopover.show(relativeTo: caretRect, of: webView, preferredEdge: .minY)
        }

        private func makeSlashPopover() -> NSPopover {
            let popover = NSPopover()
            popover.behavior = .transient
            popover.animates = true
            popover.delegate = self
            popover.contentSize = NSSize(width: 320, height: 390)
            popover.contentViewController = NSHostingController(
                rootView: NativeSlashPopoverView { [weak self] command, row, column in
                    self?.runSlashCommand(command, row: row, column: column)
                }
            )
            return popover
        }

        private func runSlashCommand(_ command: String, row: Int?, column: Int?) {
            var arguments: [String] = [command]
            if command == "table" {
                arguments.append(String(row ?? 3))
                arguments.append(String(column ?? 3))
            }
            guard let data = try? JSONSerialization.data(withJSONObject: arguments),
                  let json = String(data: data, encoding: .utf8) else { return }
            let javascript = """
            (() => {
              const args = \(json);
              const payload = args[0] === 'table' ? { row: Number(args[1]), col: Number(args[2]) } : undefined;
              window.__cvstickyPerform(args[0], payload);
              window.CVStickyWYSIWYG.setSlashPopoverOpen(false);
            })()
            """
            slashPopover?.performClose(nil)
            webView?.evaluateJavaScript(javascript)
        }

        func popoverDidClose(_ notification: Notification) {
            webView?.evaluateJavaScript("window.CVStickyWYSIWYG.setSlashPopoverOpen(false)")
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            if ["http", "https", "mailto", "file"].contains(url.scheme?.lowercased() ?? "") {
                NSWorkspace.shared.open(url)
            }
            decisionHandler(.cancel)
        }

        func webView(
            _ webView: WKWebView,
            runOpenPanelWith parameters: WKOpenPanelParameters,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping ([URL]?) -> Void
        ) {
            let panel = NSOpenPanel()
            panel.title = "选择图片"
            panel.prompt = "选择"
            panel.message = "选择要插入便签的图片"
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = parameters.allowsMultipleSelection
            panel.allowedContentTypes = [.image]

            guard let window = webView.window else {
                completionHandler(panel.runModal() == .OK ? panel.urls : nil)
                return
            }
            panel.beginSheetModal(for: window) { response in
                completionHandler(response == .OK ? panel.urls : nil)
            }
        }

        private func makeEditorContextMenu() -> NSMenu {
            let menu = NSMenu(title: "编辑")
            menu.addItem(NSMenuItem(title: "撤销", action: Selector(("undo:")), keyEquivalent: "z"))
            menu.addItem(NSMenuItem(title: "重做", action: Selector(("redo:")), keyEquivalent: "Z"))
            menu.addItem(.separator())
            menu.addItem(NSMenuItem(title: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
            menu.addItem(NSMenuItem(title: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
            menu.addItem(NSMenuItem(title: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
            menu.addItem(NSMenuItem(title: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
            menu.addItem(.separator())
            let format = NSMenu(title: "便签格式")
            for level in 1...6 {
                format.addItem(editorMenuItem("\(level) 级标题", command: "heading\(level)"))
            }
            format.addItem(.separator())
            format.addItem(editorMenuItem("粗体", command: "bold"))
            format.addItem(editorMenuItem("斜体", command: "italic"))
            format.addItem(editorMenuItem("下划线", command: "underline"))
            format.addItem(editorMenuItem("删除线", command: "strike"))
            format.addItem(editorMenuItem("行内代码", command: "code"))

            let lists = NSMenu(title: "便签列表")
            lists.addItem(editorMenuItem("无序列表", command: "bulletList"))
            lists.addItem(editorMenuItem("有序列表", command: "orderedList"))
            lists.addItem(editorMenuItem("任务列表", command: "taskList"))
            lists.addItem(editorMenuItem("引用", command: "quote"))

            let insert = NSMenu(title: "便签插入")
            insert.addItem(editorMenuItem("代码块", command: "codeBlock"))
            insert.addItem(editorMenuItem("Mermaid 流程图", command: "mermaid"))
            insert.addItem(editorMenuItem("数学公式", command: "math"))
            insert.addItem(editorMenuItem("表格（3 × 3）", command: "table", row: 3, column: 3))
            insert.addItem(.separator())
            insert.addItem(editorMenuItem("链接", command: "link"))
            insert.addItem(editorMenuItem("图片…", command: "image"))

            let formatRoot = NSMenuItem(title: "便签格式", action: nil, keyEquivalent: "")
            formatRoot.submenu = format
            let listRoot = NSMenuItem(title: "便签列表", action: nil, keyEquivalent: "")
            listRoot.submenu = lists
            let insertRoot = NSMenuItem(title: "便签插入", action: nil, keyEquivalent: "")
            insertRoot.submenu = insert
            menu.addItem(formatRoot)
            menu.addItem(listRoot)
            menu.addItem(insertRoot)
            return menu
        }

        private func editorMenuItem(
            _ title: String,
            command: String,
            row: Int? = nil,
            column: Int? = nil
        ) -> NSMenuItem {
            let item = NSMenuItem(
                title: title,
                action: #selector(runEditorMenuCommand(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = MarkdownEditorCommandRequest(
                noteID: noteID,
                command: command,
                row: row,
                column: column
            )
            return item
        }

        @objc private func runEditorMenuCommand(_ sender: NSMenuItem) {
            guard let request = sender.representedObject as? MarkdownEditorCommandRequest,
                  let javascript = javascript(for: request) else { return }
            webView?.evaluateJavaScript(javascript)
        }
    }
}

private final class FirstClickWKWebView: WKWebView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

private enum NativeSlashCategory: String, CaseIterable, Identifiable {
    case text = "文本"
    case list = "列表"
    case more = "更多"

    var id: String { rawValue }
}

private struct NativeSlashItem: Identifiable {
    let command: String
    let title: String
    let symbol: String
    var shortcut: String?

    var id: String { command }
}

private struct NativeSlashPopoverView: View {
    @State private var category: NativeSlashCategory = .text
    let onSelect: (String, Int?, Int?) -> Void

    private var items: [NativeSlashItem] {
        switch category {
        case .text:
            return [
                NativeSlashItem(command: "text", title: "正文", symbol: "textformat"),
                NativeSlashItem(command: "heading1", title: "一级标题", symbol: "textformat.size.larger", shortcut: "⌥1"),
                NativeSlashItem(command: "heading2", title: "二级标题", symbol: "textformat.size.larger", shortcut: "⌥2"),
                NativeSlashItem(command: "heading3", title: "三级标题", symbol: "textformat.size.larger", shortcut: "⌥3"),
                NativeSlashItem(command: "heading4", title: "四级标题", symbol: "textformat.size.larger", shortcut: "⌥4"),
                NativeSlashItem(command: "heading5", title: "五级标题", symbol: "textformat.size.larger", shortcut: "⌥5"),
                NativeSlashItem(command: "heading6", title: "六级标题", symbol: "textformat.size.larger", shortcut: "⌥6"),
                NativeSlashItem(command: "quote", title: "引用", symbol: "text.quote"),
                NativeSlashItem(command: "divider", title: "分隔线", symbol: "minus")
            ]
        case .list:
            return [
                NativeSlashItem(command: "bulletList", title: "无序列表", symbol: "list.bullet", shortcut: "⌘⇧8"),
                NativeSlashItem(command: "orderedList", title: "有序列表", symbol: "list.number", shortcut: "⌘⇧7"),
                NativeSlashItem(command: "taskList", title: "任务列表", symbol: "checklist")
            ]
        case .more:
            return [
                NativeSlashItem(command: "image", title: "图片…", symbol: "photo.badge.plus"),
                NativeSlashItem(command: "codeBlock", title: "代码块", symbol: "chevron.left.forwardslash.chevron.right"),
                NativeSlashItem(command: "table", title: "表格（3 × 3）", symbol: "tablecells"),
                NativeSlashItem(command: "math", title: "数学公式", symbol: "function"),
                NativeSlashItem(command: "mermaid", title: "Mermaid 流程图", symbol: "point.3.connected.trianglepath.dotted")
            ]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("插入内容")
                .font(.headline)
            Picker("类别", selection: $category) {
                ForEach(NativeSlashCategory.allCases) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Divider()

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(items) { item in
                        NativeSlashCommandRow(item: item) {
                            onSelect(
                                item.command,
                                item.command == "table" ? 3 : nil,
                                item.command == "table" ? 3 : nil
                            )
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 320, height: 390)
    }
}

private struct NativeSlashCommandRow: View {
    let item: NativeSlashItem
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: item.symbol)
                    .frame(width: 20)
                Text(item.title)
                Spacer()
                if let shortcut = item.shortcut {
                    Text(shortcut)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(hovering ? Color.accentColor.opacity(0.16) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(item.title)
    }
}
