import SwiftData
import Foundation

@Model
class Entry {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var type: EntryType = EntryType.text
    var text: String = ""
    var tags: [String] = []
    var isFavorited: Bool = false    
    // Photo
    var imageData: Data? = nil
    var extractedText: String? = nil
    var visionTags: [String] = []
    
    // Audio
    var audioData: Data? = nil
    var transcript: String? = nil
    var duration: Double? = nil
    
    // Link
    var url: String? = nil
    var linkTitle: String? = nil
    var previewImageData: Data? = nil
    var markdownContent: String? = nil
    var faviconData: Data? = nil
    
    // Location entry fields
    var locationName: String? = nil
    var locationAddress: String? = nil
    var locationLatitude: Double? = nil
    var locationLongitude: Double? = nil
    var locationCategory: String? = nil
    
    // Capture location metadata
    var captureLatitude: Double? = nil
    var captureLongitude: Double? = nil
    var captureLocationName: String? = nil
    
    // Sticky / checklist
    var stickyTitle: String? = nil
    var stickyItems: [String] = []
    var stickyChecked: [String] = []
    
    init(type: EntryType = .text, text: String = "", tags: [String] = []) {
        self.id = UUID()
        self.createdAt = Date()
        self.type = type
        self.text = text
        self.tags = tags
        self.isFavorited = false
        self.visionTags = []
    }
}

enum EntryType: String, Codable, CaseIterable {
    case text
    case photo
    case audio
    case link
    case journal
    case location
    case sticky
}
