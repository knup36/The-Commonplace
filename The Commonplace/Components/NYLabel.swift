// NYLabel.swift
// Commonplace
//
// A UIViewRepresentable that renders text in New York font at a specific size
// and weight. Required because New York is only accessible via UIFontDescriptor
// in SwiftUI — Font.custom and .system(design: .serif) don't reliably resolve
// to New York for small UI labels.

import SwiftUI
import UIKit

struct NYLabel: UIViewRepresentable {
    let text: String
    let size: CGFloat
    let weight: UIFont.Weight
    let color: UIColor

    init(
        _ text: String,
        size: CGFloat = 11,
        weight: UIFont.Weight = .regular,
        color: UIColor = .white.withAlphaComponent(0.7)
    ) {
        self.text = text
        self.size = size
        self.weight = weight
        self.color = color
    }

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
            let attributed = NSAttributedString(string: text, attributes: [
                .font: resolvedFont,
                .foregroundColor: color,
                .kern: 1.5
            ])
            label.attributedText = attributed
        }

    var resolvedFont: UIFont {
        let baseDescriptor = UIFontDescriptor
            .preferredFontDescriptor(withTextStyle: .body)
        guard let serifDescriptor = baseDescriptor.withDesign(.serif) else {
            return UIFont.systemFont(ofSize: size, weight: weight)
        }
        let weighted = serifDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight]
        ])
        return UIFont(descriptor: weighted, size: size)
    }
}
