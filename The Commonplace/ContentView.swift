import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var previousTab = 0
    
    @Environment(\.modelContext) var modelContext
    
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
            FeedView()
                .tabItem {
                    Label("Feed", systemImage: "rectangle.stack.fill")
                }
                .tag(0)
            
            CollectionsView()
                .tabItem {
                    Label("Collections", systemImage: "books.vertical.fill")
                }
                .tag(1)
            
            TagsView()
                .tabItem {
                    Label("Tags", systemImage: "tag.fill")
                }
                .tag(2)
            
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "sun.max.fill")
                }
                .tag(3)
        }
        .onChange(of: selectedTab) { old, new in
            previousTab = old
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                createDefaultCollectionsIfNeeded(context: modelContext)
            }
        }
        .fontDesign(.rounded)
    }
}
