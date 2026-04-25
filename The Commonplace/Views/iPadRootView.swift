// iPadRootView.swift
// Commonplace
//
// iPad root layout. Wraps NavigationSplitView with iPadSidebarView on the
// left and the selected tab's view on the right.
//
// Owned by ContentView — receives selectedTab, showingAddEntry, and
// showingTemplatePicker as bindings so the sidebar and main content
// stay in sync.
//
// The MiniSoundPlayerBar overlay is re-applied here since the iPhone
// TabView overlay doesn't apply on iPad.

import SwiftUI

struct iPadRootView: View {
    @Binding var selectedTab: Int
    @Binding var showingAddEntry: Bool
    @Binding var showingTemplatePicker: Bool

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        NavigationSplitView {
            iPadSidebarView(
                selectedTab: $selectedTab,
                showingAddEntry: $showingAddEntry,
                showingTemplatePicker: $showingTemplatePicker
            )
            .navigationBarHidden(true)
        } detail: {
            selectedTabView
                .overlay(alignment: .bottom) {
                    MiniSoundPlayerBar()
                }
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var selectedTabView: some View {
        switch selectedTab {
        case 0: HomeDashboardView()
        case 1: FeedView()
        case 2: LibraryView()
        case 3: ChroniclesView()
        case 4: TodayView()
        default: FeedView()
        }
    }
}
