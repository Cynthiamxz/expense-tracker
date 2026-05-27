// TransactionsView.swift
// Responsibility: Tab 2 root view — sync status bar at the top, date-grouped
//                 scrollable transaction list, and the "+" FAB that opens
//                 AddTransactionView. Delegates list state to TransactionsViewModel.
// Depends on: TransactionsViewModel, SyncService, DateGroupView, AddTransactionView,
//             Transaction model, Constants
// Used by: ContentView (Tab 1)

import SwiftUI
import SwiftData

struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authService: GmailAuthService
    @EnvironmentObject private var syncService: SyncService
    @StateObject private var viewModel = TransactionsViewModel()

    @State private var showAddSheet: Bool = false
    @State private var selectedTransaction: Transaction? = nil

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                syncBar
                transactionList
            }
            fab
        }
        .background(Color(hex: Constants.Design.background))
        .task {
            viewModel.configure(syncService: syncService, modelContext: modelContext)
            viewModel.loadTransactions()
            // Only auto-sync once per app session (when no sync has run yet).
            // Subsequent syncs are user-initiated via pull-to-refresh.
            if authService.isAuthenticated && syncService.lastSyncDate == nil {
                await viewModel.refresh()
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddTransactionView()
        }
        .sheet(item: $selectedTransaction) { tx in
            TransactionDetailView(transaction: tx, onDelete: {
                viewModel.delete(transaction: tx)
            })
        }
    }

    // MARK: - Sync bar

    private var syncStatusText: String {
        guard let date = syncService.lastSyncDate else { return "not yet synced" }
        return "synced \(DateHelpers.syncAgoString(from: date))"
    }

    private var syncBar: some View {
        HStack(spacing: 6) {
            if syncService.isSyncing {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Syncing…")
            } else {
                Image(systemName: "clock")
                Text(syncStatusText)
            }
        }
        .font(.caption.monospaced())
        .foregroundStyle(Color(hex: Constants.Design.mutedText))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(hex: Constants.Design.background))
    }

    // MARK: - Transaction list

    private var transactionList: some View {
        Group {
            if viewModel.groupedTransactions.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(viewModel.groupedTransactions, id: \.header) { section in
                        DateGroupView(
                            header: section.header,
                            transactions: section.transactions,
                            onSelect: { selectedTransaction = $0 }
                        )
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .refreshable { await viewModel.refresh() }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(Color(hex: Constants.Design.mutedText))
            Text("No transactions yet")
                .font(.headline)
                .foregroundStyle(Color(hex: Constants.Design.secondaryText))
            Text("Pull to refresh or tap + to add one manually.")
                .font(.subheadline)
                .foregroundStyle(Color(hex: Constants.Design.mutedText))
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - FAB

    private var fab: some View {
        Button {
            showAddSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color(hex: Constants.Design.fab))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
        }
        .padding(24)
    }
}

#Preview {
    TransactionsView()
        .environmentObject(GmailAuthService())
        .environmentObject(SyncService(
            fetcher:         GmailFetchService(auth: GmailAuthService()),
            parser:          EmailParserService(),
            modelContext:    try! ModelContext(ModelContainer(for: Transaction.self, Category.self)),
            labelRulesStore: LabelRulesStore()
        ))
        .modelContainer(for: [Transaction.self, Category.self], inMemory: true)
}
