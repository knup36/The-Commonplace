import SwiftUI
import SwiftData
import LinkPresentation

@main
struct CommonplaceApp: App {
    let container: ModelContainer

    init() {
        let descriptor = UIFontDescriptor
            .preferredFontDescriptor(withTextStyle: .body)
            .withDesign(.rounded)!
        UIFont(descriptor: descriptor, size: 0)

        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithDefaultBackground()

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
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance

        do {
            let schema = Schema([Entry.self, Collection.self, JournalEntry.self, Habit.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(
                for: Entry.self, Collection.self, JournalEntry.self, Habit.self,
                configurations: config
            )
        } catch {
                    fatalError("Could not create ModelContainer: \(error)")
                }
        MediaFileManager.initializeiCloudContainer()
        Task.detached {
                    _ = FileManager.default.url(
                        forUbiquityContainerIdentifier: "iCloud.com.knup36.The-Commonplace"
                    )
                }
            }

    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
        }
        .modelContainer(container)
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
}

// MARK: - Default collections
func createDefaultCollectionsIfNeeded(context: ModelContext) {
    Task { @MainActor in
        do {
            let descriptor = FetchDescriptor<Collection>()
            let existing = try context.fetch(descriptor)
            guard existing.isEmpty else { return }

            let defaults: [(name: String, icon: String, colorHex: String, type: String?, isFavorites: Bool)] = [
                ("Favorites", "star.fill", "#FFD60A", nil, true),
                ("Text", "text.alignleft", "#8E8E93", "text", false),
                ("Photos", "photo.fill", "#FF375F", "photo", false),
                ("Links", "link", "#007AFF", "link", false),
                ("Audio", "waveform", "#FF9F0A", "audio", false),
                ("Locations", "mappin.circle.fill", "#30D158", "location", false),
                ("Journal", "bookmark.fill", "#BF5AF2", "journal", false),
                ("Stickies", "checklist", "#FFD60A", "sticky", false)
            ]

            for (index, item) in defaults.enumerated() {
                let collection = Collection(
                    name: item.name,
                    icon: item.icon,
                    colorHex: item.colorHex,
                    order: index
                )
                if let type = item.type {
                    collection.filterTypes = [type]
                }
                if item.isFavorites {
                    collection.filterSearchText = "__favorites__"
                }
                collection.isSystem = true
                context.insert(collection)
            }

            try context.save()
        } catch {
            print("Default collections error: \(error)")
        }
    }
}
