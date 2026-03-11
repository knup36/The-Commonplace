import Foundation
import SwiftSoup

class ArticleExtractor {
    
    static func extract(from urlString: String) async -> (title: String?, markdown: String?, error: String?) {
        guard let url = URL(string: urlString) else {
            return (nil, nil, "Invalid URL")
        }
        
        do {
            // Fetch the page
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                return (nil, nil, "Could not load page")
            }
            
            let doc = try SwiftSoup.parse(html)
            
            // Extract title
            let title = try doc.title()
            
            // Remove unwanted elements
            try doc.select("script, style, nav, header, footer, iframe, aside, .ad, .advertisement, .sidebar, .menu, .navigation, .cookie, .popup, .modal, .banner").remove()
            
            // Try to find main content
            let contentSelectors = [
                "article",
                "[role='main']",
                ".article-body",
                ".post-content",
                ".entry-content",
                ".article-content",
                ".story-body",
                "main",
                ".content"
            ]
            
            var contentElement: Element? = nil
            for selector in contentSelectors {
                if let element = try doc.select(selector).first() {
                    contentElement = element
                    break
                }
            }
            
            // Fall back to body if no content element found
            let element = contentElement ?? doc.body()
            guard let element else {
                return (title, nil, "Could not extract content")
            }
            
            // Convert to markdown
            let markdown = try convertToMarkdown(element: element, title: title)
            
            return (title.isEmpty ? nil : title, markdown.isEmpty ? nil : markdown, nil)
            
        } catch {
            return (nil, nil, "Extraction failed: \(error.localizedDescription)")
        }
    }
    
    private static func convertToMarkdown(element: Element, title: String) throws -> String {
        var lines: [String] = []
        
        if !title.isEmpty {
            lines.append("# \(title)")
            lines.append("")
        }
        
        try processElement(element: element, lines: &lines, depth: 0)
        
        // Clean up excessive blank lines
        var result = lines.joined(separator: "\n")
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func processElement(element: Element, lines: inout [String], depth: Int) throws {
        let tag = element.tagName().lowercased()
        
        switch tag {
        case "h1":
            let text = try element.text().trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { lines.append("# \(text)"); lines.append("") }
        case "h2":
            let text = try element.text().trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { lines.append("## \(text)"); lines.append("") }
        case "h3":
            let text = try element.text().trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { lines.append("### \(text)"); lines.append("") }
        case "h4", "h5", "h6":
            let text = try element.text().trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { lines.append("#### \(text)"); lines.append("") }
        case "p":
            let text = try element.text().trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { lines.append(text); lines.append("") }
        case "blockquote":
            let text = try element.text().trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                let quoted = text.split(separator: "\n").map { "> \($0)" }.joined(separator: "\n")
                lines.append(quoted)
                lines.append("")
            }
        case "li":
            let text = try element.text().trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { lines.append("- \(text)") }
        case "ul", "ol":
            for child in element.children() {
                try processElement(element: child, lines: &lines, depth: depth + 1)
            }
            lines.append("")
        case "br":
            lines.append("")
        case "hr":
            lines.append("---")
            lines.append("")
        case "strong", "b":
            // Handled inline by parent
            break
        case "em", "i":
            // Handled inline by parent
            break
        case "code":
            let text = try element.text()
            if !text.isEmpty { lines.append("`\(text)`") }
        case "pre":
            let text = try element.text()
            if !text.isEmpty {
                lines.append("```")
                lines.append(text)
                lines.append("```")
                lines.append("")
            }
        default:
            // For div and other containers, process children
            for child in element.children() {
                try processElement(element: child, lines: &lines, depth: depth)
            }
        }
    }
}
