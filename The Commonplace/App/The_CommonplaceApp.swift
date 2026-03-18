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
                forUbiquityContainerIdentifier: "iCloud.com.johncaldwell.commonplace"
            )
        }
    }

    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
                .task {
                    await startupTasks()
                }
        }
        .modelContainer(container)
    }

    // MARK: - Startup

    @MainActor
    func startupTasks() async {
        let context = container.mainContext
        migrateJournalEntriesToEntries(context: context)
        do {
            let entries = try context.fetch(FetchDescriptor<Entry>())
            SearchIndex.shared.backfillIfNeeded(entries: entries)
        } catch {
            print("Backfill fetch failed: \(error)")
        }
    }

    // MARK: - Journal Entry Migration

    @MainActor
    func migrateJournalEntriesToEntries(context: ModelContext) {
        let migrationKey = "journalEntryMigrationComplete"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        do {
            let journalEntries = try context.fetch(FetchDescriptor<JournalEntry>())
            guard !journalEntries.isEmpty else {
                UserDefaults.standard.set(true, forKey: migrationKey)
                return
            }

            let entries = try context.fetch(FetchDescriptor<Entry>())

            for je in journalEntries {
                let matchingEntry = entries.first {
                    $0.type == .journal &&
                    Calendar.current.isDate($0.createdAt, inSameDayAs: je.date)
                }

                if let entry = matchingEntry {
                    entry.weatherEmoji = je.weatherEmoji
                    entry.moodEmoji = je.moodEmoji
                    entry.completedHabits = je.completedHabits
                    entry.completedHabitSnapshots = je.completedHabitSnapshots
                    entry.totalHabitsAtTime = je.totalHabitsAtTime
                    entry.journalImageData = je.journalImageData
                } else {
                    let entry = Entry(type: .journal, text: "", tags: [])
                    entry.createdAt = je.date
                    entry.weatherEmoji = je.weatherEmoji
                    entry.moodEmoji = je.moodEmoji
                    entry.completedHabits = je.completedHabits
                    entry.completedHabitSnapshots = je.completedHabitSnapshots
                    entry.totalHabitsAtTime = je.totalHabitsAtTime
                    entry.journalImageData = je.journalImageData
                    context.insert(entry)
                }

                context.delete(je)
            }

            try context.save()
            UserDefaults.standard.set(true, forKey: migrationKey)
            print("Journal migration complete: \(journalEntries.count) entries migrated")
        } catch {
            print("Journal migration failed: \(error)")
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
}

// MARK: - Default collections
func createDefaultCollectionsIfNeeded(context: ModelContext) {
    Task { @MainActor in
        do {
            let descriptor = FetchDescriptor<Collection>()
            let existing = try context.fetch(descriptor)
            let existingNames = Set(existing.map { $0.name })

            let defaults: [(name: String, icon: String, colorHex: String, type: String?, isFavorites: Bool)] = [
                ("Favorites",  "star.fill",          "#FFD60A", nil,        true),
                ("Text",       "text.alignleft",      "#8E8E93", "text",     false),
                ("Photos",     "photo.fill",          "#FF375F", "photo",    false),
                ("Links",      "link",                "#007AFF", "link",     false),
                ("Audio",      "waveform",            "#FF9F0A", "audio",    false),
                ("Locations",  "mappin.circle.fill",  "#34C759", "location", false),
                ("Journal",    "bookmark.fill",       "#AF52DE", "journal",  false),
                ("Stickies",   "checklist",           "#FFD60A", "sticky",   false),
                ("Music",      "music.note",          "#C87858", "music",    false)
            ]

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
