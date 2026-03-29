import SwiftUI
import SwiftData
import LinkPresentation

@main
struct CommonplaceApp: App {
    let container: ModelContainer
    
    init() {
        // Read saved theme before ThemeManager is available
        let savedTheme = UserDefaults.standard.string(forKey: "appTheme") ?? "System"
        let useRounded = savedTheme != "Inkwell"
        
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithDefaultBackground()
        
        if useRounded {
            // System theme — apply rounded font globally
            if let roundedDescriptor = UIFontDescriptor
                .preferredFontDescriptor(withTextStyle: .largeTitle)
                .withDesign(.rounded) {
                navBarAppearance.largeTitleTextAttributes = [
                    .font: UIFont(descriptor: roundedDescriptor, size: 0)
                ]
            }
            if let roundedDescriptor = UIFontDescriptor
                .preferredFontDescriptor(withTextStyle: .headline)
                .withDesign(.rounded) {
                navBarAppearance.titleTextAttributes = [
                    .font: UIFont(descriptor: roundedDescriptor, size: 0)
                ]
            }
            if let roundedDescriptor = UIFontDescriptor
                .preferredFontDescriptor(withTextStyle: .body)
                .withDesign(.rounded) {
                UIFont(descriptor: roundedDescriptor, size: 0)
            }
        }
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        
        do {
            let schema = Schema([Entry.self, Collection.self, Habit.self, Tag.self, Person.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(
                for: Entry.self, Collection.self, Habit.self, Tag.self, Person.self,
                configurations: config
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        MediaFileManager.initializeiCloudContainer()
        Task.detached {
            _ = FileManager.default.url(
                forUbiquityContainerIdentifier: "iCloud.com.johncaldwell.commonplace"
            )
        }
    }
    
    @StateObject private var themeManager = ThemeManager()
    
    @Environment(\.scenePhase) var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
                .task {
                    await startupTasks()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        let context = container.mainContext
                        ShareExtensionIngestor.ingestPendingEntries(context: context)
                    }
                }
        }
        .modelContainer(container)
    }
    
    // MARK: - Startup
    
    @MainActor
    func startupTasks() async {
        do {
            let context = container.mainContext
            let entries = try context.fetch(FetchDescriptor<Entry>())
            SearchIndex.shared.backfillIfNeeded(entries: entries)
            TagMigrationService.migrateIfNeeded(context: context)
            PersonMigrationService.migrateIfNeeded(context: context)
            ShareExtensionIngestor.ingestPendingEntries(context: context)
            Task.detached {
                await HealthKitBackfillService.shared.backfillIfNeeded(
                    entries: entries,
                    context: context
                )
            }
        } catch {
            print("Backfill fetch failed: \(error)")
        }
    }}

// MARK: - Shake gesture support
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}

// MARK: - Notification names
extension Notification.Name {
    static let deviceDidShake = Notification.Name("deviceDidShake")
    static let musicPlaybackStarted = Notification.Name("musicPlaybackStarted")
    
}

