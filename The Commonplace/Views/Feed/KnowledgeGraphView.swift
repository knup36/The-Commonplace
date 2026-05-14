// KnowledgeGraphView.swift
// Commonplace
//
// WKWebView wrapper that hosts the D3 force-directed knowledge graph.
// Loads knowledge_graph.html from the app bundle and injects entry/tag
// data as JSON via evaluateJavaScript once the page has loaded.
//
// Communication model:
//   Swift → JS: evaluateJavaScript("loadGraph(<json>)")
//   JS → Swift: WKScriptMessageHandler "entryTapped" with entry UUID string
//
// iPad-only. Never instantiated on iPhone.

import SwiftUI
import WebKit

struct KnowledgeGraphView: UIViewRepresentable {
    let entries: [Entry]
        let tags: [Tag]
        let theme: AppTheme
    var onEntryTapped: (String) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onEntryTapped: onEntryTapped)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "entryTapped")
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        
        context.coordinator.webView = webView
        context.coordinator.entries = entries
                context.coordinator.tags = tags
                context.coordinator.theme = theme
        
        if let url = Bundle.main.url(forResource: "knowledge_graph", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let countChanged = context.coordinator.entries.count != entries.count
        context.coordinator.entries = entries
                context.coordinator.tags = tags
                context.coordinator.theme = theme
        if countChanged {
            context.coordinator.injectDataIfReady()
        }
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var onEntryTapped: (String) -> Void
        var webView: WKWebView?
        var entries: [Entry] = []
                var tags: [Tag] = []
                var theme: AppTheme = .dusk
        var isReady = false
        var hasInjected = false
        
        init(onEntryTapped: @escaping (String) -> Void) {
            self.onEntryTapped = onEntryTapped
        }
        
        // Called when the HTML page finishes loading
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isReady = true
            injectDataIfReady()
        }
        
        func injectDataIfReady() {
            guard isReady, let webView, !hasInjected else { return }
            hasInjected = true

            // Match the WebView background to the app theme background color
            let bgHex: String
                switch theme {
                case .inkwell: bgHex = "#000000"
                case .dusk:    bgHex = "#000000"
                default:       bgHex = "#000000"
                }
            webView.evaluateJavaScript("document.body.style.background = '\(bgHex)'") { _, _ in }

            let json = GraphDataService.buildJSON(entries: entries, tags: tags, theme: theme)
            let escaped = json
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")
            webView.evaluateJavaScript("loadGraph('\(escaped)')") { _, error in
                if let error { print("Graph inject error: \(error)") }
            }
        }
        
        // Called when JS fires window.webkit.messageHandlers.entryTapped.postMessage(id)
        func userContentController(_ userContentController: WKUserContentController,
                                           didReceive message: WKScriptMessage) {
                    guard message.name == "entryTapped",
                          let id = message.body as? String else { return }
                    if id.hasPrefix("DEBUG") {
                        print(id)
                        return
                    }
                    onEntryTapped(id)
                }
    }
}
