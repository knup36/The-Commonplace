// GiftCardView.swift
// Commonplace
//
// Inline contextual Gift Card — appears in CollectionDetailView when
// a relevant entry qualifies. Warm silver treatment, dismissable with X.
//
// On dismiss: snoozes the card for 30 days, card remains in Chronicles archive.
// On tap action: navigates to the associated entry.

import SwiftUI

struct GiftCardView: View {
    let card: GiftCard
    var onDismiss: () -> Void
    var onAction: () -> Void
    @State private var shimmerAngle: Double = 0
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: card.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
            }
            
            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(card.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.95))
                Text(card.message)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                
                Button {
                    onAction()
                } label: {
                    Text("Open Entry")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            
            Spacer()
            
            // Dismiss
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .padding(6)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#4A4A52"), Color(hex: "#32323A")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            AngularGradient(
                                colors: [
                                    Color(hex: "#4A4A52"),
                                    Color(hex: "#4A4A52"),
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0.7),
                                    Color.white,
                                    Color.white.opacity(0.7),
                                    Color.white.opacity(0.15),
                                    Color(hex: "#4A4A52"),
                                    Color(hex: "#4A4A52")
                                ],
                                center: .center,
                                startAngle: .degrees(shimmerAngle),
                                endAngle: .degrees(shimmerAngle + 360)
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                .onAppear {
                    withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                        shimmerAngle = 360
                    }
                }
    }
}
