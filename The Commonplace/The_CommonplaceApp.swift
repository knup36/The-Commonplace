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
        
        // Apply rounded font to navigation bar titles
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
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    @StateObject private var themeManager = ThemeManager()

        var body: some Scene {
            WindowGroup {
                ContentView()
                    .environmentObject(themeManager)
                    .preferredColorScheme(themeManager.colorScheme)
                    .onAppear {
                        processShareQueue()
                    }
            }
            .modelContainer(container)
        }
    
    func processShareQueue() {
        let queued = ShareQueue.load()
        guard !queued.isEmpty else { return }
        Task {
            for item in queued {
                await saveQueuedEntry(item)
            }
            ShareQueue.clear()
        }
    }
    
    func saveQueuedEntry(_ item: QueuedEntry) async {
        do {
            let context = ModelContext(container)
            
            let entryType = EntryType(rawValue: item.type) ?? .text
            let entry = Entry(type: entryType, text: item.text, tags: item.tags)
            entry.createdAt = item.date
            
            switch entryType {
            case .link:
                entry.url = item.url
                if let urlString = item.url {
                    let fetcher = LinkPreviewFetcher()
                    await fetcher.fetch(urlString: urlString)
                    if let metadata = fetcher.metadata {
                        entry.linkTitle = metadata.title
                        if let imageProvider = metadata.imageProvider {
                            imageProvider.loadObject(ofClass: UIImage.self) { image, _ in
                                if let image = image as? UIImage,
                                   let data = image.jpegData(compressionQuality: 0.7) {
                                    entry.previewImageData = data
                                }
                            }
                        }
                        if let iconProvider = metadata.iconProvider {
                            iconProvider.loadObject(ofClass: UIImage.self) { icon, _ in
                                if let icon = icon as? UIImage,
                                   let data = icon.pngData() {
                                    entry.faviconData = data
                                }
                            }
                        }
                    }
                }
            case .photo:
                entry.imageData = item.imageData
                if let imageData = item.imageData {
                    let result = await VisionService.analyze(imageData: imageData)
                    entry.extractedText = result.extractedText.isEmpty ? nil : result.extractedText
                }
            default:
                break
            }
            
            context.insert(entry)
            try context.save()
        } catch {
            print("Save error: \(error)")
        }
    }
}
    
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}
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
                    context.insert(collection)                }
                
                try context.save()            } catch {
                print("Default collections error: \(error)")
            }
        }
    }

extension Notification.Name {
    static let deviceDidShake = Notification.Name("deviceDidShake")
}
