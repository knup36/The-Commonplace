import Foundation

struct QueuedEntry: Codable {
    var id: String
    var type: String
    var text: String
    var url: String?
    var imageData: Data?
    var date: Date
    var tags: [String]
    
    init(type: String, text: String = "", url: String? = nil, imageData: Data? = nil) {
        self.id = UUID().uuidString
        self.type = type
        self.text = text
        self.url = url
        self.imageData = imageData
        self.date = Date()
        self.tags = []
    }
}

class ShareQueue {
    static let key = "queued_entries"
    static let defaults = UserDefaults(suiteName: "commonplace.share") ?? UserDefaults.standard
    
    static func save(_ entries: [QueuedEntry]) {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: key)
            defaults.synchronize()
        }
    }
    
    static func load() -> [QueuedEntry] {
        guard let data = defaults.data(forKey: key),
              let entries = try? JSONDecoder().decode([QueuedEntry].self, from: data) else {
            return []
        }
        return entries
    }
    
    static func append(_ entry: QueuedEntry) {
        var current = load()
        current.append(entry)
        save(current)
    }
    
    static func clear() {
        defaults.removeObject(forKey: key)
        defaults.synchronize()
    }
}
