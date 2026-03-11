import SwiftData
import Foundation

enum CommonplaceSchema: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [Entry.self, Collection.self]
    }
}
