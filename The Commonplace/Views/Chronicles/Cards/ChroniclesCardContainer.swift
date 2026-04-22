// ChroniclesCardContainer.swift
// Commonplace
//
// Shared card container used by all Chronicles cards.
// Provides consistent visual treatment — dark amber gradient background,
// gold border, amber section header with icon.
//
// Usage:
//   ChroniclesCardContainer(title: "On This Day", icon: "calendar") {
//       // card content here
//   }

import SwiftUI

enum ChroniclesCardBackground {
    case dark       // default — deep amber brown
    case parchment  // off-white beige — for memory/archive cards
}

struct ChroniclesCardContainer<Content: View>: View {
    let title: String
    let icon: String
    let cardID: String
    var background: ChroniclesCardBackground = .dark
    @ViewBuilder let content: () -> Content
    
    @AppStorage var isExpanded: Bool
    
    init(title: String, icon: String, cardID: String, background: ChroniclesCardBackground = .dark, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.cardID = cardID
        self.background = background
        self.content = content
        self._isExpanded = AppStorage(wrappedValue: true, "chronicles_expanded_\(cardID)")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ChroniclesTheme.accentAmber)
                    Text(title.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .kerning(0.8)
                        .foregroundStyle(ChroniclesTheme.accentAmber)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ChroniclesTheme.accentAmber)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            
            if isExpanded {
                content()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(background == .parchment
                      ? AnyShapeStyle(LinearGradient(
                        colors: [Color(hex: "#4A4A52"), Color(hex: "#32323A")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      ))
                      : AnyShapeStyle(ChroniclesTheme.cardGradient)
                     )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: background == .parchment
                                ? [Color.white.opacity(0.18), Color.black.opacity(0.25)]
                                : [Color.white.opacity(0.10), Color.black.opacity(0.20)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            background == .parchment
                            ? AnyShapeStyle(Color(hex: "#6A6A72").opacity(0.5))
                            : AnyShapeStyle(ChroniclesTheme.cardBorderGradient),
                            lineWidth: 0.5
                        )
                )
        )
        .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)
        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
    }
}
