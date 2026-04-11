import SwiftUI

// MARK: - ContentView
// Root tab bar for the app.
// Tab order: Home · Feed · Library · Chronicles · Today
// This is the final tab structure — do not add intermediate tabs.

struct ContentView: View {
    @State private var selectedTab = 1
    @State private var previousTab = 0
    
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var themeManager: ThemeManager
    
    init() {
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithDefaultBackground()
        
        if let roundedDescriptor = UIFontDescriptor
            .preferredFontDescriptor(withTextStyle: .largeTitle)
            .withDesign(.rounded)?
            .withSymbolicTraits(.traitBold) {
            navBarAppearance.largeTitleTextAttributes = [
                .font: UIFont(descriptor: roundedDescriptor, size: 34)
            ]
        }
        if let roundedDescriptor = UIFontDescriptor
            .preferredFontDescriptor(withTextStyle: .headline)
            .withDesign(.rounded)?
            .withSymbolicTraits(.traitBold) {
            navBarAppearance.titleTextAttributes = [
                .font: UIFont(descriptor: roundedDescriptor, size: 17)
            ]
        }
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeDashboardView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            FeedView()
                .tabItem {
                    Label("Feed", systemImage: "rectangle.stack.fill")
                }
                .tag(1)
            
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical.fill")
                }
                .tag(2)
            
            ChroniclesView()
                .tabItem {
                    Label("Chronicles", systemImage: ChroniclesTheme.icon)
                }
                .tag(3)
            
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "sun.max.fill")
                }
                .tag(4)
        }
        .onChange(of: selectedTab) { old, new in
            previousTab = old
            // Tab 2 was Search (keyboard dismiss needed) — now Library, no longer needed
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            }
        }
        .fontDesign(themeManager.current == .inkwell ? .serif : .rounded)
        .overlay(alignment: .bottom) {
            VStack {
                Spacer()
                MiniSoundPlayerBar()
                    .padding(.bottom, 57)
            }
        }
    }
}
