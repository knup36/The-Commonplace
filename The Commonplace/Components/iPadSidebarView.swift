// iPadSidebarView.swift
// Commonplace
//
// iPad-only sidebar navigation component. Replaces the tab bar on iPad.
// Renders inside NavigationSplitView as the sidebar column.
//
// Structure (top to bottom):
//   - App title
//   - 5 tab navigation items (Home, Feed, Library, Chronicles, Today)
//   - Recents section (7 most recently modified entries)
//   - Spacer
//   - ThoughtCaptureBar pinned at bottom (isInSidebar: true)
//
// The selectedTab binding is owned by ContentView and shared with the
// main content column so both stay in sync.
//
// Recents use entry type accent colors from the active theme for their
// subtitle labels, matching the visual language of feed cards.

import SwiftUI
import SwiftData

struct iPadSidebarView: View {
    @Binding var selectedTab: Int
    @Binding var showingAddEntry: Bool
    @Binding var showingTemplatePicker: Bool
    
    @EnvironmentObject var themeManager: ThemeManager
    @Query(sort: \Entry.modifiedAt, order: .reverse) var recentEntries: [Entry]
    
    var style: any AppThemeStyle { themeManager.style }
    
    private var recents: [Entry] {
        Array(recentEntries.prefix(7))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // MARK: - App title
            Text("Commonplace")
                .font(style.typeSectionHeader)
                .foregroundStyle(style.tertiaryText)
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 12)
            
            // MARK: - Tabs
            VStack(spacing: 2) {
                iPadTabRow(icon: "house.fill",         label: "Home",        tag: 0)
                iPadTabRow(icon: "rectangle.stack.fill", label: "Feed",      tag: 1)
                iPadTabRow(icon: "books.vertical.fill", label: "Library",    tag: 2)
                iPadTabRow(icon: ChroniclesTheme.icon,  label: "Chronicles", tag: 3)
                iPadTabRow(icon: "sun.max.fill",        label: "Today",      tag: 4)
            }
            .padding(.horizontal, 12)
            
            // MARK: - Recents
            if !recents.isEmpty {
                Text("Recents")
                    .font(style.typeSectionHeader)
                    .foregroundStyle(style.tertiaryText)
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 12)
                
                VStack(spacing: 2) {
                    ForEach(recents) { entry in
                        iPadRecentRow(entry: entry)
                    }
                }
                .padding(.horizontal, 12)
            }
            
            Spacer()
            
            // MARK: - Capture bar
            Divider()
                .padding(.bottom, 4)
            
            ThoughtCaptureBar(
                isInSidebar: true,
                showingAddEntry: $showingAddEntry,
                showingTemplatePicker: $showingTemplatePicker
            )
            .padding(.bottom, 12)
        }
    }
    
    // MARK: - Tab row
    @ViewBuilder
    private func iPadTabRow(icon: String, label: String, tag: Int) -> some View {
        Button {
            selectedTab = tag
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 20)
                Text(label)
                    .font(style.typeBody)
                Spacer()
            }
            .foregroundStyle(selectedTab == tag ? style.accent : style.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                selectedTab == tag
                ? style.accent.opacity(0.08)
                : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Recent row
    @ViewBuilder
    private func iPadRecentRow(entry: Entry) -> some View {
        Button {
            selectedTab = 1
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(iPadSidebarView.recentTitle(for: entry))
                    .font(style.typeBodySecondary)
                    .fontWeight(.medium)
                    .foregroundStyle(style.primaryText)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(entry.type.displayName)
                    Text("·")
                    Text(entry.modifiedAt.sidebarRelative)
                }
                .font(style.typeCaption)
                .foregroundStyle(entry.type.accentColor(for: themeManager.current))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helpers
    
    static func recentTitle(for entry: Entry) -> String {
        switch entry.type {
        case .text, .audio:
            return entry.text.components(separatedBy: "\n").first ?? "Untitled"
        case .sticky:
            return entry.stickyTitle ?? "Untitled"
        case .link:
            return entry.linkTitle ?? entry.url ?? "Untitled"
        case .location:
            return entry.locationName ?? "Untitled"
        case .music:
            return entry.text.isEmpty ? "Untitled" : entry.text
        case .photo:
            return entry.text.isEmpty ? "Shot" : entry.text.components(separatedBy: "\n").first ?? "Shot"
        case .media:
            return entry.mediaTitle ?? "Untitled"
        case .journal:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d"
            return formatter.string(from: entry.createdAt)
        case .attachment:
            return entry.attachmentFilename ?? "Attachment"
        }
    }
}

// MARK: - Date extension

private extension Date {
    var sidebarRelative: String {
        let seconds = Date().timeIntervalSince(self)
        switch seconds {
        case ..<3600:
            let mins = max(1, Int(seconds / 60))
            return "\(mins)m ago"
        case ..<86400:
            let hours = Int(seconds / 3600)
            return "\(hours)h ago"
        case ..<172800:
            return "Yesterday"
        default:
            let days = Int(seconds / 86400)
            return "\(days)d ago"
        }
    }
}
