// FlowLayout.swift
// Commonplace
//
// A reusable wrapping layout for pill-style content.
// Arranges views left to right, wrapping to new rows as needed.
// maxRows caps the number of rows shown.
//
// Usage:
//   FlowLayout(spacing: 8, maxRows: 3) {
//       ForEach(tags) { tag in
//           TagPill(tag: tag)
//       }
//   }
//
// Used in: HomeDashboardView (Tags section), SearchView (Tags results)

import SwiftUI

struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    let maxRows: Int
    @ViewBuilder let content: Content

    var body: some View {
        _FlowLayout(spacing: spacing, maxRows: maxRows) {
            content
        }
    }
}

private struct _FlowLayout: Layout {
    let spacing: CGFloat
    let maxRows: Int

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(subviews: subviews, width: proposal.width ?? 0)
        let rows = min(result.rows, maxRows)
        let height = result.rowHeights.prefix(rows).reduce(0, +) + CGFloat(max(0, rows - 1)) * spacing
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, width: bounds.width)
        var y = bounds.minY
        for (rowIndex, row) in result.rowItems.enumerated() {
            guard rowIndex < maxRows else { break }
            var x = bounds.minX
            for item in row {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += result.rowHeights[rowIndex] + spacing
        }
    }

    struct LayoutResult {
        var rows: Int
        var rowHeights: [CGFloat]
        var rowItems: [[(index: Int, size: CGSize)]]
    }

    func layout(subviews: Subviews, width: CGFloat) -> LayoutResult {
        var rows: [[(index: Int, size: CGSize)]] = [[]]
        var rowWidths: [CGFloat] = [0]
        var rowHeights: [CGFloat] = [0]

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let currentRow = rows.count - 1
            let currentWidth = rowWidths[currentRow]

            if currentWidth + size.width + (currentWidth > 0 ? spacing : 0) > width && currentWidth > 0 {
                rows.append([(index: index, size: size)])
                rowWidths.append(size.width)
                rowHeights.append(size.height)
            } else {
                let addSpacing = currentWidth > 0 ? spacing : 0
                rows[currentRow].append((index: index, size: size))
                rowWidths[currentRow] += size.width + addSpacing
                rowHeights[currentRow] = max(rowHeights[currentRow], size.height)
            }
        }

        return LayoutResult(rows: rows.count, rowHeights: rowHeights, rowItems: rows)
    }
}
