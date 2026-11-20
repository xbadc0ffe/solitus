import Foundation
import SwiftData

/// Version 1 of the stored schema: the three Tasks models plus the settings
/// record.
///
/// The app uses a versioned schema and a migration plan from the first build
/// (DESIGN.md section 5). Adding a property with an inline default is a
/// lightweight change and needs nothing here. A change SwiftData cannot infer
/// needs a `TasksSchemaV2` with frozen copies of the old models and a stage
/// in `TasksMigrationPlan`.
nonisolated enum TasksSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [TaskItem.self, Entry.self, Slot.self, AppSettings.self]
    }
}

nonisolated enum TasksMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [TasksSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
