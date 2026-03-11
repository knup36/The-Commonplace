import SwiftData

enum CommonplaceMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [CommonplaceSchema.self]
    }
    
    static var stages: [MigrationStage] {
        // No stages yet — V1 is our starting point
        // When we add fields in the future, migration stages go here
        []
    }
}
