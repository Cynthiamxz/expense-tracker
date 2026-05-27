// TransactionsViewModel.swift
// Responsibility: Drives the Transactions tab — groups fetched transactions by
//                 calendar date for the sectioned list, manages pull-to-refresh,
//                 and exposes the sync status text shown in the sync bar.
// Depends on: SwiftData, SyncService, Transaction model, DateHelpers
// Used by: TransactionsView (observes groupedTransactions, syncStatusText)

import Foundation
import SwiftData

@MainActor
class TransactionsViewModel: ObservableObject {
    @Published var groupedTransactions: [(header: String, transactions: [Transaction])] = []

    private var syncService: SyncService?
    private var modelContext: ModelContext?

    init() {}

    func configure(syncService: SyncService, modelContext: ModelContext) {
        self.syncService = syncService
        self.modelContext = modelContext
    }

    func loadTransactions() {
        guard let modelContext else { return }

        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let all = try? modelContext.fetch(descriptor) else { return }

        var buckets: [String: (date: Date, txs: [Transaction])] = [:]
        for tx in all {
            let key = DateHelpers.groupKey(for: tx.date)
            if buckets[key] == nil { buckets[key] = (date: tx.date, txs: []) }
            buckets[key]!.txs.append(tx)
        }

        groupedTransactions = buckets
            .sorted { $0.key > $1.key }
            .map { _, value in
                (header: DateHelpers.sectionHeader(for: value.date), transactions: value.txs)
            }
    }

    func refresh() async {
        await syncService?.sync()
        loadTransactions()
    }

    func delete(transaction: Transaction) {
        modelContext?.delete(transaction)
        loadTransactions()
    }
}
