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
            let schema = Schema([Entry.self, Collection.self, Habit.self, Tag.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(
                for: Entry.self, Collection.self, Habit.self, Tag.self,
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
            
            // Debug — check App Group container
            if let url = AppGroupContainer.pendingEntriesURL {
                print("📦 App Group pending folder: \(url.path)")
                let files = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
                print("📦 Pending files: \(files)")
            } else {
                print("📦 App Group container unavailable!")
            }
            
            ShareExtensionIngestor.ingestPendingEntries(context: context)
        } catch {
            print("Backfill fetch failed: \(error)")
            
        }
    }
}

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

// MARK: - Default collections
func createDefaultCollectionsIfNeeded(context: ModelContext) {
    Task { @MainActor in
        do {
            let descriptor = FetchDescriptor<Collection>()
            let existing = try context.fetch(descriptor)
            let existingNames = Set(existing.map { $0.name })
            let defaults: [(name: String, icon: String, colorHex: String, type: String?, isFavorites: Bool)] = []

            let nextOrder = existing.map { $0.order }.max().map { $0 + 1 } ?? 0
            var created = 0

            for (index, item) in defaults.enumerated() {
                guard !existingNames.contains(item.name) else { continue }
                let collection = Collection(
                    name: item.name,
                    icon: item.icon,
                    colorHex: item.colorHex,
                    order: nextOrder + index
                )
                if let type = item.type {
                    collection.filterTypes = [type]
                }
                if item.isFavorites {
                    collection.filterSearchText = "__favorites__"
                }
                collection.isSystem = true
                context.insert(collection)
                created += 1
            }

            if created > 0 {
                try context.save()
                print("Default collections: created \(created) missing collections")
            }
        } catch {
            print("Default collections error: \(error)")
        }
    }
}
