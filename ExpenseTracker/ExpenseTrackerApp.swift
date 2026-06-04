// ExpenseTrackerApp.swift
// Responsibility: @main app entry point. Configures the SwiftData ModelContainer,
//                 constructs the service graph (auth → fetcher → parser → sync),
//                 seeds default categories on first launch, and injects all services
//                 into the environment for child views.
// Depends on: SwiftData, GmailAuthService, GmailFetchService, EmailParserService,
//             SyncService, Category (seeding), Constants
// Used by: iOS runtime (entry point — nothing depends on this file directly)

import SwiftUI
import SwiftData

@main
struct ExpenseTrackerApp: App {
    // Static so it can be referenced in init() before `self` is fully initialised.
    // Declared as a let at type level to guarantee it's created exactly once.
    private static let labelRulesStore = LabelRulesStore()

    // Bump this whenever a stored @Model property is added or renamed.
    // The mismatch triggers a proactive store wipe before SwiftData reads any rows.
    private static let schemaVersion    = 4
    private static let schemaVersionKey = "app_schema_version"

    private static let container: ModelContainer = {
        let schema = Schema([Transaction.self, Category.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        // Wipe the store when the schema version changes. This prevents SwiftData
        // from crashing when it tries to decode existing rows that are missing new
        // non-optional columns (e.g. `currency` added in schema v2).
        // Replace with VersionedSchema + SchemaMigrationPlan before shipping.
        let stored = UserDefaults.standard.integer(forKey: schemaVersionKey)
        if stored != schemaVersion {
            try? FileManager.default.removeItem(at: config.url)
            UserDefaults.standard.set(schemaVersion, forKey: schemaVersionKey)
        }

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            try? FileManager.default.removeItem(at: config.url)
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Could not create ModelContainer after store reset: \(error)")
            }
        }
    }()

    @StateObject private var authService: GmailAuthService
    @StateObject private var syncService: SyncService

    // Build the full service graph here so every service gets exactly one instance
    // shared across the whole app lifetime.
    // container.mainContext is the @MainActor model context — correct for SyncService.
    init() {
        let auth = GmailAuthService()
        _authService = StateObject(wrappedValue: auth)
        _syncService = StateObject(wrappedValue: SyncService(
            fetcher:         GmailFetchService(auth: auth),
            parser:          EmailParserService(),
            modelContext:    Self.container.mainContext,
            labelRulesStore: Self.labelRulesStore
        ))
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .modelContainer(Self.container)
                .environmentObject(authService)
                .environmentObject(syncService)
                .environmentObject(Self.labelRulesStore)
        }
    }
}

// Bridges @Environment(\.modelContext) into the launch sequence before handing
// off to ContentView. Also the single place where first-launch seeding happens.
struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authService: GmailAuthService

    var body: some View {
        ContentView()
            .task {
                authService.checkExistingAuth()
                seedCategoriesIfNeeded()
            }
    }

    private func seedCategoriesIfNeeded() {
        let count = (try? modelContext.fetchCount(FetchDescriptor<Category>())) ?? 0
        guard count == 0 else { return }
        Category.seedDefaults(into: modelContext)
    }
}
