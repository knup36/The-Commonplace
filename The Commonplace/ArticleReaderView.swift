import SwiftUI

struct ArticleReaderView: View {
    let markdown: String
    let title: String?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // Render markdown line by line
                    ForEach(parsedBlocks, id: \.id) { block in
                        blockView(block)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Markdown Parser
    
    struct MarkdownBlock: Identifiable {
        let id = UUID()
        let type: BlockType
        let content: String
        
        enum BlockType {
            case h1, h2, h3, h4
            case paragraph
            case bulletPoint
            case blockquote
            case code
            case divider
            case empty
        }
    }
    
    var parsedBlocks: [MarkdownBlock] {
            var lines = markdown.components(separatedBy: "\n")
            
        // Remove leading empty lines
                while lines.first?.trimmingCharacters(in: .whitespaces).isEmpty == true {
                    lines.removeFirst()
                }
                // Remove first heading (H1 or H2) since it's the article title
                if let firstHeading = lines.firstIndex(where: { $0.hasPrefix("# ") || $0.hasPrefix("## ") }) {
                    lines.remove(at: firstHeading)
                    // Also remove the empty line after it if present
                    if firstHeading < lines.count && lines[firstHeading].trimmingCharacters(in: .whitespaces).isEmpty {
                        lines.remove(at: firstHeading)
                    }
                }
            
            return lines.map { line in
            if line.hasPrefix("# ") {
                return MarkdownBlock(type: .h1, content: String(line.dropFirst(2)))
            } else if line.hasPrefix("## ") {
                return MarkdownBlock(type: .h2, content: String(line.dropFirst(3)))
            } else if line.hasPrefix("### ") {
                return MarkdownBlock(type: .h3, content: String(line.dropFirst(4)))
            } else if line.hasPrefix("#### ") {
                return MarkdownBlock(type: .h4, content: String(line.dropFirst(5)))
            } else if line.hasPrefix("- ") {
                return MarkdownBlock(type: .bulletPoint, content: String(line.dropFirst(2)))
            } else if line.hasPrefix("> ") {
                return MarkdownBlock(type: .blockquote, content: String(line.dropFirst(2)))
            } else if line.hasPrefix("```") {
                return MarkdownBlock(type: .code, content: String(line.dropFirst(3)))
            } else if line == "---" {
                return MarkdownBlock(type: .divider, content: "")
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                return MarkdownBlock(type: .empty, content: "")
            } else {
                return MarkdownBlock(type: .paragraph, content: line)
            }
        }
    }
    
    @ViewBuilder
    func blockView(_ block: MarkdownBlock) -> some View {
        switch block.type {
        case .h1:
            Text(block.content)
                .font(.title)
                .fontWeight(.bold)
        case .h2:
            Text(block.content)
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 8)
        case .h3:
            Text(block.content)
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.top, 4)
        case .h4:
            Text(block.content)
                .font(.headline)
                .padding(.top, 4)
        case .paragraph:
            Text(block.content)
                .font(.body)
                .lineSpacing(4)
        case .bulletPoint:
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(.body)
                Text(block.content)
                    .font(.body)
                    .lineSpacing(4)
            }
        case .blockquote:
            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color.indigo)
                    .frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                Text(block.content)
                    .font(.body)
                    .italic()
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
            }
            .padding(.vertical, 4)
        case .code:
            Text(block.content)
                .font(.system(.caption, design: .monospaced))
                .padding(8)
                .background(Color(uiColor: .systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        case .divider:
            Divider()
        case .empty:
            EmptyView()
        }
    }
}
