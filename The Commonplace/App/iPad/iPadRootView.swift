// iPadRootView.swift
// Commonplace
//
// iPad root layout. Wraps a three-column NavigationSplitView:
//   - Sidebar column: iPadSidebarView (tab nav + recents + ThoughtCaptureBar)
//   - Content column: the selected tab's primary view
//   - Detail column: entry detail panel per tab
//
// Navigation state is owned by NavigationRouter (injected via @EnvironmentObject).
// iPadRootView reads from the router directly — no local @State for navigation,
// no callback handlers, no asyncAfter hacks. All navigation changes are atomic.
//
// Each content column view has a stable .id() matching its tab number so that
// SwiftUI fully rebuilds it when switching tabs, resetting any nested
// NavigationStack to its root automatically.
//
// iPhone: completely unaffected — ContentView still shows the iPhone layout.
// The router's @Published iPad properties are never read on iPhone.
//
// The MiniSoundPlayerBar overlay is applied here since the iPhone
// TabView overlay doesn't apply on iPad.

import SwiftUI

struct iPadRootView: View {
    @Binding var showingAddEntry: Bool
    @Binding var showingTemplatePicker: Bool
    
    @EnvironmentObject var router: NavigationRouter
    @EnvironmentObject var themeManager: ThemeManager
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            iPadSidebarView(
                selectedTab: $router.iPadSelectedTab,
                showingAddEntry: $showingAddEntry,
                showingTemplatePicker: $showingTemplatePicker
            )
            .navigationBarHidden(true)
        } content: {
            contentColumn
                .navigationBarHidden(true)
                .navigationSplitViewColumnWidth(min: router.iPadFeedIsNodeMode ? 500 : 390, ideal: router.iPadFeedIsNodeMode ? 700 : 390)
        } detail: {
            detailColumn
                .overlay(alignment: .bottom) {
                    MiniSoundPlayerBar()
                }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbarBackground(.hidden, for: .navigationBar)
                .onChange(of: router.iPadFeedIsNodeMode) { _, isNodeMode in
            withAnimation(.easeInOut(duration: 0.35)) {
                columnVisibility = isNodeMode ? .doubleColumn : .all
            }
        }
    }
    
    // MARK: - Content Column
    
    @ViewBuilder
    private var contentColumn: some View {
        switch router.iPadSelectedTab {
        case 1:
            iPadFeedView(
                selectedEntry: $router.selectedFeedEntry,
                showingAddEntry: $showingAddEntry,
                showingTemplatePicker: $showingTemplatePicker
            )
            .id("feed-\(router.iPadFeedResetToken)")
        case 2:
            iPadLibraryView(selectedEntry: $router.selectedLibraryEntry)
                .id(2)
        case 4:
            TodayView(onSelectEntry: { entry in
                router.selectedTodayEntry = entry
            })
            .id(4)
        case 0:
            iPadHomeView(selectedEntry: $router.selectedHomeEntry)
                .id(0)
        case 3:
            ChroniclesView()
                .id(3)
        default:
            EmptyView()
        }
    }
    
    // MARK: - Detail Column
    
    @ViewBuilder
    private var detailColumn: some View {
        switch router.iPadSelectedTab {
        case 1:
            iPadEntryDetailPanel(selectedEntry: $router.selectedFeedEntry)
        case 2:
            iPadEntryDetailPanel(selectedEntry: $router.selectedLibraryEntry)
        case 4:
            iPadEntryDetailPanel(selectedEntry: $router.selectedTodayEntry)
        case 0:
            iPadEntryDetailPanel(selectedEntry: $router.selectedHomeEntry)
        case 3:
            iPadEntryDetailPanel(selectedEntry: $router.selectedChroniclesEntry)
        default:
            style.background.ignoresSafeArea()
        }
    }
    
    private var style: any AppThemeStyle { themeManager.style }
}
