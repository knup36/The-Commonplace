// iPadRootView.swift
// Commonplace
//
// iPad root layout. Wraps a three-column NavigationSplitView:
//   - Sidebar column: iPadSidebarView (tab nav + recents + ThoughtCaptureBar)
//   - Content column: the selected tab's primary view
//   - Detail column: entry detail panel (iPadFeedDetailPanel when Feed is active)
//
// selectedFeedEntry is owned here and passed as a binding to both
// iPadFeedView (sets it on tap) and iPadFeedDetailPanel (reads it to render).
//
// Non-feed tabs currently render their existing views in the content column
// with the detail column empty — each tab will get its own iPad treatment
// in subsequent sessions.
//
// The MiniSoundPlayerBar overlay is applied here since the iPhone
// TabView overlay doesn't apply on iPad.

import SwiftUI

struct iPadRootView: View {
    @Binding var selectedTab: Int
    @Binding var showingAddEntry: Bool
    @Binding var showingTemplatePicker: Bool
    
    @State private var selectedFeedEntry: Entry? = nil
        @State private var selectedLibraryEntry: Entry? = nil
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationSplitView {
            iPadSidebarView(
                selectedTab: $selectedTab,
                showingAddEntry: $showingAddEntry,
                showingTemplatePicker: $showingTemplatePicker
            )
            .navigationBarHidden(true)
        } content: {
            contentColumn
                .navigationBarHidden(true)
        } detail: {
            detailColumn
                .overlay(alignment: .bottom) {
                    MiniSoundPlayerBar()
                }
        }
        .navigationSplitViewStyle(.balanced)
    }
    
    // MARK: - Content Column
    
    @ViewBuilder
    private var contentColumn: some View {
        switch selectedTab {
        case 1:
            iPadFeedView(
                selectedEntry: $selectedFeedEntry,
                showingAddEntry: $showingAddEntry,
                showingTemplatePicker: $showingTemplatePicker
            )
        case 2:
                    iPadLibraryView(selectedEntry: $selectedLibraryEntry)
        default:
            selectedTabView
        }
    }
    
    // MARK: - Detail Column
    
    @ViewBuilder
    private var detailColumn: some View {
        switch selectedTab {
        case 1:
            iPadFeedDetailPanel(selectedEntry: $selectedFeedEntry)
        case 2:
                    iPadLibraryDetailPanel(selectedEntry: $selectedLibraryEntry)
        default:
            // Other tabs will get detail panels in subsequent iPad sessions
            style.background.ignoresSafeArea()
        }
    }
    
    // MARK: - Non-feed tab views (temporary — will each get iPad treatment)
    
    @ViewBuilder
    private var selectedTabView: some View {
        switch selectedTab {
        case 0: HomeDashboardView()
        case 3: ChroniclesView()
        case 4: TodayView()
        default: EmptyView()
        }
    }
    
    private var style: any AppThemeStyle { themeManager.style }
}
