// iPadRootView.swift
// Commonplace
//
// iPad root layout. Wraps a three-column NavigationSplitView:
//   - Sidebar column: iPadSidebarView (tab nav + recents + ThoughtCaptureBar)
//   - Content column: the selected tab's primary view
//   - Detail column: entry detail panel per tab
//
// Selected entry state is owned here per tab and passed as bindings:
//   - selectedFeedEntry    → iPadFeedView + iPadFeedDetailPanel       (tab 1)
//   - selectedLibraryEntry → iPadLibraryView + iPadLibraryDetailPanel (tab 2)
//   - selectedTodayEntry   → TodayView + iPadTodayDetailPanel         (tab 4)
//
// Non-feed tabs without iPad treatment yet (Home tab 0, Chronicles tab 3)
// render their existing views in the content column with an empty detail column.
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
    @State private var selectedTodayEntry: Entry? = nil
    @State private var selectedHomeEntry: Entry? = nil
    
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
        case 4:
            TodayView(onSelectEntry: { entry in
                selectedTodayEntry = entry
            })
        case 0:
            iPadHomeView(selectedEntry: $selectedHomeEntry)
        default:
            selectedTabView
        }
    }
    
    // MARK: - Detail Column
    
    @ViewBuilder
    private var detailColumn: some View {
        switch selectedTab {
        case 1:
                    iPadEntryDetailPanel(selectedEntry: $selectedFeedEntry)
                case 2:
                    iPadEntryDetailPanel(selectedEntry: $selectedLibraryEntry)
        case 4:
            iPadEntryDetailPanel(selectedEntry: $selectedTodayEntry)
        case 0:
            iPadEntryDetailPanel(selectedEntry: $selectedHomeEntry)
        default:
            // Home and Chronicles will get detail panels in subsequent iPad sessions
            style.background.ignoresSafeArea()
        }
    }
    
    // MARK: - Non-iPad-treated tab views
    
    @ViewBuilder
        private var selectedTabView: some View {
            switch selectedTab {
            case 3: ChroniclesView()
            default: EmptyView()
            }
        }
    
    private var style: any AppThemeStyle { themeManager.style }
}
