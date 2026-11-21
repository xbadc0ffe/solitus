import Foundation
import SwiftData

/// Builds the SwiftData container.
///
/// The store lives in the App Group container so widgets can share it later
/// (DESIGN.md section 3). The app is local only: CloudKit is switched off.
enum ModelContainerFactory {
    static let appGroupID = "group.com.badc0ffe.solitus"

    static var schema: Schema {
        Schema(versionedSchema: TasksSchemaV1.self)
    }

    /// Opens the app's store, trying in order:
    ///
    /// 1. The store in the App Group container.
    /// 2. The store in the app's own container (if the App Group is not
    ///    available, for example in an unsigned build).
    /// 3. An in-memory store, so the app still launches.
    ///
    /// `isPersistent` is false only in the last case.
    static func makeAppContainer() -> (container: ModelContainer, isPersistent: Bool) {
        // Make sure Application Support exists before SwiftData touches it;
        // on a fresh install it does not, and SwiftData logs a long
        // diagnostic before recovering.
        _ = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let schema = self.schema

        // Ask the file manager first. On a device, building a
        // ModelConfiguration for a group the app is not entitled to does not
        // throw; it stops the process.
        if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil {
            let grouped = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                groupContainer: .identifier(appGroupID),
                cloudKitDatabase: .none
            )
            if let container = try? makeContainer(schema: schema, configuration: grouped) {
                return (container, true)
            }
        }

        let local = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        if let container = try? makeContainer(schema: schema, configuration: local) {
            return (container, true)
        }

        do {
            return (try makeInMemoryContainer(), false)
        } catch {
            // An in-memory container has no I/O to fail on. If even this
            // throws, the schema itself is broken and there is nothing to run.
            fatalError("Could not create an in-memory ModelContainer: \(error)")
        }
    }

    /// A container that keeps nothing on disk, for tests and previews.
    static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = self.schema
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        return try makeContainer(schema: schema, configuration: configuration)
    }

    private static func makeContainer(schema: Schema, configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            migrationPlan: TasksMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
