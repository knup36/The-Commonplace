// ScrapbookMediaCard.swift
// Commonplace
//
// Scrapbook feed card for .media entries.
// Renders as a vintage ticket stub — perforated border around main body,
// concave corners, "ADMIT ONE" header, title in Impact font, rating, date.
//
// Layout:
//   - Main ticket body (left) with cover art + content
//   - Perforated dot border around main body
//   - Perforated divider line separating stub
//   - Stub (right) with vertical "ADMIT" text
//
// Color cycles through 4 vintage ticket colors based on entry UUID.
// Slight rotation seeded from UUID.
// TicketShape provides concave corners and semicircle notches.

import SwiftUI

struct ScrapbookMediaCard: View {
    let entry: Entry

    static let ticketColors: [(bg: Color, text: Color)] = [
        (Color(red: 0.72, green: 0.10, blue: 0.10), Color(red: 1.0,  green: 0.92, blue: 0.85)),
        (Color(red: 0.15, green: 0.35, blue: 0.45), Color(red: 0.85, green: 0.95, blue: 0.98)),
        (Color(red: 0.45, green: 0.28, blue: 0.08), Color(red: 1.0,  green: 0.93, blue: 0.78)),
        (Color(red: 0.28, green: 0.18, blue: 0.45), Color(red: 0.92, green: 0.88, blue: 1.00)),
    ]

    var ticketColor: (bg: Color, text: Color) {
        let hash = abs(entry.id.uuidString.hashValue)
        return Self.ticketColors[hash % Self.ticketColors.count]
    }

    var rotation: Double {
        let hash = abs(entry.id.uuidString.hashValue)
        let normalized = Double(hash % 600) / 100.0
        return normalized - 3.0
    }

    var starRating: String {
        guard let rating = entry.mediaRating else { return "" }
        let full = Int(rating)
        let empty = 5 - full
        return String(repeating: "★", count: full) + String(repeating: "☆", count: empty)
    }

    private let stubWidth: CGFloat = 36
    private let cardHeight: CGFloat = 130

    var body: some View {
        HStack(spacing: 0) {

            // Main ticket body
            HStack(spacing: 10) {
                // Cover art thumbnail
                if let coverPath = entry.mediaCoverPath,
                   let data = MediaFileManager.load(path: coverPath),
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 70, height: cardHeight)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(ticketColor.bg.opacity(0.5))
                        .frame(width: 70, height: cardHeight)
                        .overlay(
                            Image(systemName: "film")
                                .font(.system(size: 24))
                                .foregroundStyle(ticketColor.text.opacity(0.4))
                        )
                }

                // Content — fixed layout
                VStack(alignment: .leading, spacing: 0) {
                    // Admit one — always top
                    Text("ADMIT ONE")
                        .font(.system(size: 8, weight: .bold))
                        .kerning(2)
                        .foregroundStyle(ticketColor.text.opacity(0.6))
                        .padding(.leading, 12)
                        .padding(.bottom, 8)

                    // Title
                    Text(entry.mediaTitle ?? "Unknown")
                        .font(.custom("Impact", size: 18))
                        .foregroundStyle(ticketColor.text)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.7)

                    // Year + genre + rating inline
                    HStack(spacing: 4) {
                        if let year = entry.mediaYear {
                            Text(year)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(ticketColor.text.opacity(0.7))
                        }
                        if let genre = entry.mediaGenre {
                            Text("·")
                                .foregroundStyle(ticketColor.text.opacity(0.4))
                            Text(genre)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(ticketColor.text.opacity(0.7))
                                .lineLimit(1)
                        }
                        if !starRating.isEmpty {
                            Text("·")
                                .foregroundStyle(ticketColor.text.opacity(0.4))
                            Text(starRating)
                                .font(.system(size: 9))
                                .foregroundStyle(ticketColor.text.opacity(0.9))
                        }
                    }
                    .padding(.top, 2)

                    Spacer(minLength: 0)

                    // Date — always bottom
                    Text(entry.createdAt.formatted(.dateTime.month(.abbreviated).day().year()).uppercased())
                        .font(.system(size: 8, weight: .semibold))
                        .kerning(1)
                        .foregroundStyle(ticketColor.text.opacity(0.5))
                        .padding(.leading, 12)
                        .padding(.top, 6)
                }
                .padding(.vertical, 14)
                .padding(.trailing, 8)
                .frame(height: cardHeight)
            }
            .frame(maxWidth: .infinity, minHeight: cardHeight)
            .background(ticketColor.bg)
            .overlay(
                PerforatedBorder(color: ticketColor.text.opacity(0.35))
            )

            // Perforated divider
            PerforatedDivider(color: ticketColor.text.opacity(0.3))
                .frame(width: 12, height: cardHeight)
                .background(ticketColor.bg)

            // Stub
            ZStack {
                ticketColor.bg.opacity(0.85)
                Text("ADMIT")
                    .font(.system(size: 9, weight: .bold))
                    .kerning(2)
                    .foregroundStyle(ticketColor.text.opacity(0.6))
                    .fixedSize()
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: stubWidth, height: cardHeight)
        }
        .frame(height: cardHeight)
        .clipShape(TicketShape())
        .shadow(color: .black.opacity(0.25), radius: 6, x: 2, y: 4)
        .rotationEffect(.degrees(rotation))
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Perforated Divider

struct PerforatedDivider: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let dotDiameter: CGFloat = 4
            let spacing: CGFloat = 8
            var y: CGFloat = spacing
            while y < size.height {
                let rect = CGRect(
                    x: (size.width - dotDiameter) / 2,
                    y: y,
                    width: dotDiameter,
                    height: dotDiameter
                )
                context.fill(Path(ellipseIn: rect), with: .color(color))
                y += spacing + dotDiameter
            }
        }
    }
}

// MARK: - Perforated Border

struct PerforatedBorder: View {
    let color: Color
    private let dotDiameter: CGFloat = 3
    private let spacing: CGFloat = 7
    private let inset: CGFloat = 6

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(
                x: inset,
                y: inset,
                width: size.width - inset * 2,
                height: size.height - inset * 2
            )

            var x = rect.minX
            while x <= rect.maxX {
                let r = CGRect(x: x, y: rect.minY - dotDiameter/2, width: dotDiameter, height: dotDiameter)
                context.fill(Path(ellipseIn: r), with: .color(color))
                x += spacing + dotDiameter
            }

            x = rect.minX
            while x <= rect.maxX {
                let r = CGRect(x: x, y: rect.maxY - dotDiameter/2, width: dotDiameter, height: dotDiameter)
                context.fill(Path(ellipseIn: r), with: .color(color))
                x += spacing + dotDiameter
            }

            var y = rect.minY
            while y <= rect.maxY {
                let r = CGRect(x: rect.minX - dotDiameter/2, y: y, width: dotDiameter, height: dotDiameter)
                context.fill(Path(ellipseIn: r), with: .color(color))
                y += spacing + dotDiameter
            }

            y = rect.minY
            while y <= rect.maxY {
                let r = CGRect(x: rect.maxX - dotDiameter/2, y: y, width: dotDiameter, height: dotDiameter)
                context.fill(Path(ellipseIn: r), with: .color(color))
                y += spacing + dotDiameter
            }
        }
    }
}

// MARK: - Ticket Shape

struct TicketShape: Shape {
    let cornerRadius: CGFloat = 8
    let notchRadius: CGFloat = 8
    let notchX: CGFloat = UIScreen.main.bounds.width - 16 * 2 - 36 - 12

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Top-left concave corner
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
        path.addArc(
            center: CGPoint(x: rect.minX, y: rect.minY),
            radius: cornerRadius,
            startAngle: .degrees(90),
            endAngle: .degrees(0),
            clockwise: true
        )

        // Top edge — left to notch
        path.addLine(to: CGPoint(x: notchX - notchRadius, y: rect.minY))

        // Top notch cutout
        path.addArc(
            center: CGPoint(x: notchX, y: rect.minY),
            radius: notchRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: true
        )

        // Top edge — notch to right
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))

        // Top-right concave corner
        path.addArc(
            center: CGPoint(x: rect.maxX, y: rect.minY),
            radius: cornerRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(90),
            clockwise: true
        )

        // Right edge
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))

        // Bottom-right concave corner
        path.addArc(
            center: CGPoint(x: rect.maxX, y: rect.maxY),
            radius: cornerRadius,
            startAngle: .degrees(270),
            endAngle: .degrees(180),
            clockwise: true
        )

        // Bottom edge — right to notch
        path.addLine(to: CGPoint(x: notchX + notchRadius, y: rect.maxY))

        // Bottom notch cutout
        path.addArc(
            center: CGPoint(x: notchX, y: rect.maxY),
            radius: notchRadius,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: true
        )

        // Bottom edge — notch to left
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))

        // Bottom-left concave corner
        path.addArc(
            center: CGPoint(x: rect.minX, y: rect.maxY),
            radius: cornerRadius,
            startAngle: .degrees(0),
            endAngle: .degrees(270),
            clockwise: true
        )

        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
        path.closeSubpath()
        return path
    }
}
