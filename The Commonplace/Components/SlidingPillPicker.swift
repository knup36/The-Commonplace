// SlidingPillPicker.swift
// Commonplace
//
// A reusable segmented picker with a sliding pill animation and
// skeuomorphic recessed track. Replaces all hand-rolled HStack
// button pickers and native Picker(.segmented) instances in detail views.
//
// Generic over any Hashable selection type — works with String, Int,
// enums, or any other Hashable value.
//
// Usage (with icons and per-option selected colors):
//   SlidingPillPicker(
//       options: [
//           .init(label: "Watchlist", value: "wantTo",   icon: "bookmark",        selectedColor: .blue),
//           .init(label: "Watched",   value: "finished", icon: "checkmark.circle", selectedColor: .green)
//       ],
//       selection: $localStatus,
//       accentColor: accentColor
//   )
//
// Usage (labels only, no icons):
//   SlidingPillPicker(
//       options: [
//           .init(label: "7 days",   value: 0),
//           .init(label: "4 weeks",  value: 1),
//           .init(label: "3 months", value: 2)
//       ],
//       selection: $selectedWindow,
//       accentColor: accentColor
//   )
//
// Design notes:
//   - Recessed track: black.opacity(0.15) fill + black.opacity(0.25) border
//   - Sliding pill: accentColor.opacity(0.18) fill + accentColor.opacity(0.35) border
//   - Pill animates with spring(response: 0.3, dampingFraction: 0.75) — same as HabitPatternsCard
//   - Selected icon/label: uses option.selectedColor if provided, else accentColor
//   - Unselected icon/label: accentColor.opacity(0.4)
//   - Icon and label stacked vertically when icon is present, inline when nil
//   - Component height auto-sizes: 32pt for label-only, 44pt for icon+label

import SwiftUI

// MARK: - PillPickerOption

struct PillPickerOption<T: Hashable> {
    let label: String
    let value: T
    var icon: String? = nil
    var selectedColor: Color? = nil
}

// MARK: - SlidingPillPicker

struct SlidingPillPicker<T: Hashable>: View {
    let options: [PillPickerOption<T>]
    @Binding var selection: T
    var accentColor: Color

    private var hasIcons: Bool {
        options.contains { $0.icon != nil }
    }

    private var controlHeight: CGFloat {
        hasIcons ? 48 : 32
    }

    var body: some View {
        GeometryReader { geo in
            let segmentWidth = geo.size.width / CGFloat(options.count)
            let selectedIndex = options.firstIndex { $0.value == selection } ?? 0

            ZStack(alignment: .leading) {
                // Recessed track
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.black.opacity(0.25), lineWidth: 0.5)
                    )

                // Sliding pill
                RoundedRectangle(cornerRadius: 8)
                    .fill(accentColor.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(accentColor.opacity(0.35), lineWidth: 0.5)
                    )
                    .frame(width: segmentWidth - 4)
                    .offset(x: CGFloat(selectedIndex) * segmentWidth + 2)
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: selectedIndex)

                // Labels (and icons)
                HStack(spacing: 0) {
                    ForEach(Array(options.enumerated()), id: \.offset) { i, option in
                        let isSelected = option.value == selection
                        let foreground = isSelected
                            ? (option.selectedColor ?? accentColor)
                            : accentColor.opacity(0.4)

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                selection = option.value
                            }
                        } label: {
                            if hasIcons, let icon = option.icon {
                                VStack(spacing: 3) {
                                    Image(systemName: isSelected ? selectedIcon(icon) : icon)
                                        .font(.system(size: 12))
                                    Text(option.label)
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                }
                                .foregroundStyle(foreground)
                                .frame(width: segmentWidth)
                                .animation(.easeInOut(duration: 0.2), value: isSelected)
                            } else {
                                Text(option.label)
                                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular, design: .rounded))
                                    .foregroundStyle(foreground)
                                    .frame(width: segmentWidth)
                                    .animation(.easeInOut(duration: 0.2), value: isSelected)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: controlHeight)
        }
        .frame(height: controlHeight)
    }

    // MARK: - Icon Fill Helper
    //
    // Mirrors the pattern used in the hand-rolled status pickers:
    // selected state uses the ".fill" variant of the SF Symbol where available.
    // If the icon already ends in ".fill" or has no fill variant, returns as-is.

    private func selectedIcon(_ icon: String) -> String {
            let fillVariants: [String: String] = [
                "bookmark":              "bookmark.fill",
                "checkmark.circle":      "checkmark.circle.fill",
                "play.circle":           "play.circle.fill",
                "arrow.clockwise.circle":"arrow.clockwise.circle.fill",
                "gamecontroller":        "gamecontroller.fill",
                "book":                  "book.fill",
                "doc.text":              "doc.text.fill",
                "link":                  "link",          // no fill variant — use as-is
                "film.fill":             "film.fill"
            ]
            return fillVariants[icon] ?? icon
        }
}
