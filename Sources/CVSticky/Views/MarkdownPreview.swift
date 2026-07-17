import SwiftUI
import WebKit

struct MarkdownPreview: NSViewRepresentable {
    let markdown: String
    let note: Note
    let darkMode: Bool
    var onTaskToggle: ((Int, Bool) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(onTaskToggle: onTaskToggle) }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.add(context.coordinator, name: "taskToggle")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.lastSignature = ""
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let signature = "\(markdown.hashValue)-\(darkMode)-\(note.id)"
        context.coordinator.onTaskToggle = onTaskToggle
        guard signature != context.coordinator.lastSignature else { return }
        context.coordinator.lastSignature = signature
        webView.loadHTMLString(html(), baseURL: note.folderURL)
    }

    private func html() -> String {
        let marked = resource("marked.umd", extension: "js")
        let katex = resource("katex.min", extension: "js")
        let mermaid = resource("mermaid.min", extension: "js")
        let katexCSS = resource("katex.min", extension: "css")
        let encoded = Data(markdown.utf8).base64EncodedString()
        let foreground = darkMode ? "#f5f5f7" : "#1d1d1f"
        let secondary = darkMode ? "#a1a1a6" : "#6e6e73"
        let surface = darkMode ? "rgba(255,255,255,.06)" : "rgba(0,0,0,.045)"
        return """
        <!doctype html><html><head><meta charset="utf-8"><style>
        \(katexCSS)
        :root{color-scheme:\(darkMode ? "dark" : "light")}*{box-sizing:border-box}body{margin:0;padding:26px 30px;background:transparent;color:\(foreground);font:15px -apple-system,BlinkMacSystemFont,sans-serif;line-height:1.65}a{color:#0a84ff}img{max-width:100%;border-radius:12px}pre{padding:14px 16px;border-radius:12px;background:\(surface);overflow:auto}code{font:13px ui-monospace,SFMono-Regular,Menlo,monospace}blockquote{margin-left:0;padding-left:14px;border-left:3px solid #0a84ff;color:\(secondary)}table{border-collapse:collapse;width:100%}th,td{border:1px solid \(secondary);padding:7px 10px;text-align:left}hr{border:0;border-top:1px solid \(secondary)}.mermaid{background:\(surface);padding:14px;border-radius:12px}.task-list-item{list-style:none}input[type=checkbox]{margin-right:8px}
        </style></head><body><main id="content"></main><script>\(marked)</script><script>\(katex)</script><script>\(mermaid)</script><script>
        const source=decodeURIComponent(escape(atob('\(encoded)')));
        const renderer=new marked.Renderer();
        renderer.code=function(code,lang){if((lang||'').trim()==='mermaid')return '<div class="mermaid">'+code.replaceAll('&','&amp;').replaceAll('<','&lt;')+'</div>';return '<pre><code class="language-'+(lang||'text')+'">'+code.replaceAll('&','&amp;').replaceAll('<','&lt;')+'</code></pre>'};
        marked.setOptions({gfm:true,breaks:true,renderer});
        let html=marked.parse(source);
        html=html.replace(/\\$\\$([\\s\\S]+?)\\$\\$/g,(_,v)=>katex.renderToString(v,{displayMode:true,throwOnError:false})).replace(/\\$([^\\n$]+?)\\$/g,(_,v)=>katex.renderToString(v,{throwOnError:false}));
        document.getElementById('content').innerHTML=html;
        const escapeHTML=s=>s.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;');
        document.querySelectorAll('pre code').forEach(el=>{let value=escapeHTML(el.textContent);value=value.replace(/(&quot;|&#39;|"|')([^\\n]*?)\\1/g,'<span style="color:#ff7ab2">$&</span>').replace(/\\b(func|function|let|var|const|class|struct|enum|if|else|for|while|return|async|await|throws|import|from|pub|fn|impl|match|true|false|null|nil|None|def|self)\\b/g,'<span style="color:#bf5af2;font-weight:600">$1</span>').replace(/(\\/\\/[^\\n]*|#[^\\n]*)/g,'<span style="color:#6c7986">$1</span>');el.innerHTML=value});
        document.querySelectorAll('input[type=checkbox]').forEach((box,index)=>{box.disabled=false;box.dataset.taskIndex=index;box.addEventListener('change',()=>window.webkit.messageHandlers.taskToggle.postMessage({index:index,checked:box.checked}))});
        mermaid.initialize({startOnLoad:false,theme:'\(darkMode ? "dark" : "default")'});mermaid.run({querySelector:'.mermaid'}).catch(()=>{});
        </script></body></html>
        """
    }

    private func resource(_ name: String, extension ext: String) -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return text
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var lastSignature = ""
        var onTaskToggle: ((Int, Bool) -> Void)?
        init(onTaskToggle: ((Int, Bool) -> Void)?) { self.onTaskToggle = onTaskToggle }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "taskToggle",
                  let body = message.body as? [String: Any],
                  let index = body["index"] as? Int,
                  let checked = body["checked"] as? Bool else { return }
            DispatchQueue.main.async { self.onTaskToggle?(index, checked) }
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
            if ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}
