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
    var imagePath: String? = nil
    var extractedText: String? = nil
    var visionTags: [String] = []
    
    // Audio
    var audioPath: String? = nil
    var transcript: String? = nil
    var duration: Double? = nil
    
    // Link
    var url: String? = nil
    var linkTitle: String? = nil
    var previewImagePath: String? = nil
    var markdownContent: String? = nil
    var faviconPath: String? = nil
    
    // Music
    var mediaArtist: String? = nil
    var mediaAlbum: String? = nil
    var previewURL: String? = nil
    var mediaArtworkPath: String? = nil
    
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
    case music

    var icon: String {
        switch self {
        case .text:     return "text.alignleft"
        case .photo:    return "photo.fill"
        case .audio:    return "waveform"
        case .link:     return "link"
        case .journal:  return "bookmark.fill"
        case .location: return "mappin.circle.fill"
        case .sticky:   return "checklist"
        case .music:    return "music.note"
        }
    }

    var displayName: String {
        switch self {
        case .text:     return "Note"
        case .photo:    return "Photo"
        case .audio:    return "Audio"
        case .link:     return "Link"
        case .journal:  return "Journal"
        case .location: return "Place"
        case .sticky:   return "List"
        case .music:    return "Music"
        }
    }
}
