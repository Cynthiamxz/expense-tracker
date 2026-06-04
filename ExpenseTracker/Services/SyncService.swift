// SyncService.swift
// Responsibility: Orchestrates the full sync pipeline on each app open or
//                 pull-to-refresh: fetch new Gmail message IDs → fetch bodies →
//                 parse → deduplicate → insert into SwiftData. Owns the last-sync
//                 timestamp that the UI reads.
// Depends on: GmailFetchService, EmailParserService, SwiftData (ModelContext)
// Used by: TransactionsViewModel (calls sync() on appear and refresh),
//          ExpenseTrackerApp (injects as @StateObject for app-level access)

import Foundation
import SwiftData

@MainActor
class SyncService: ObservableObject {
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date? = nil
    @Published var errorMessage: String? = nil

    private let fetcher: GmailFetchService
    private let parser: EmailParserService
    private let modelContext: ModelContext
    private let labelRulesStore: LabelRulesStore

    init(fetcher: GmailFetchService, parser: EmailParserService,
         modelContext: ModelContext, labelRulesStore: LabelRulesStore) {
        self.fetcher          = fetcher
        self.parser           = parser
        self.modelContext     = modelContext
        self.labelRulesStore  = labelRulesStore
    }

    // MARK: - Public API

    // Main entry point — called from TransactionsViewModel on appear and pull-to-refresh.
    // Guards against concurrent calls (e.g. if the user pulls to refresh while a sync
    // is already in flight). Individual parse failures are swallowed so that one bad
    // email doesn't abort the entire batch; network/auth errors surface to the UI.
    func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        errorMessage = nil
        defer { isSyncing = false }

        do {
            // Step 1 — collect Gmail IDs already stored so we skip them.
            let existingIds = try existingGmailIds()

            // Step 2 — fetch raw message data for IDs not yet in SwiftData.
            let newMessages = try await fetcher.fetchNewMessages(
                existingIds: existingIds,
                labels: labelRulesStore.enabledLabels
            )

            // Step 3 — parse and insert. Parse failures are logged but don't abort the batch.
            var insertedCount = 0
            for (id, data) in newMessages {
                guard let transaction = parser.parse(
                    messageId: id, data: data,
                    templates: labelRulesStore.allEnabledTemplates
                ) else { continue }
                modelContext.insert(transaction)
                insertedCount += 1
            }

            // Step 4 — persist only if there is something new to save.
            if insertedCount > 0 {
                try modelContext.save()
                print("[Sync] Inserted \(insertedCount) new transaction(s).")
            } else {
                print("[Sync] No new transactions found.")
            }

            lastSyncDate = Date.now

        } catch {
            errorMessage = friendlyMessage(for: error)
            print("[Sync] ❌ Sync failed: \(error)")
        }
    }

    // MARK: - Private helpers

    private func friendlyMessage(for error: Error) -> String {
        let raw = error.localizedDescription
        if raw.contains("400") || raw.contains("401") || raw.contains("invalid_grant") {
            return "Gmail session expired — reconnect in Settings"
        }
        if raw.contains("not signed in") || raw.contains("Not signed in") {
            return "Not connected to Gmail — tap Settings"
        }
        if raw.contains("network") || raw.contains("offline") || raw.contains("-1009") {
            return "No internet connection"
        }
        return "Sync failed — check Settings"
    }

    // Returns the set of Gmail message IDs already persisted in SwiftData.
    // Fetches only non-manual transactions since manual entries have nil gmailMessageId.
    private func existingGmailIds() throws -> Set<String> {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { !$0.isManual }
        )
        let transactions = try modelContext.fetch(descriptor)
        return Set(transactions.compactMap(\.gmailMessageId))
    }
}
