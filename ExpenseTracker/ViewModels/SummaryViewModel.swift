// SummaryViewModel.swift
// Responsibility: Drives the Summary tab — computes monthly totals, category
//                 spending breakdowns for the donut chart, and manages month
//                 navigation state. Receives live transactions from SummaryView's
//                 @Query so the chart stays in sync with SwiftData changes.
// Depends on: SwiftData, Transaction model, Category model, DateHelpers
// Used by: SummaryView (observes all @Published properties)

import Foundation
import SwiftData

@MainActor
class SummaryViewModel: ObservableObject {
    @Published var selectedMonth: Date = Date()
    @Published var totalSpent: Double = 0.0
    @Published var totalIncome: Double = 0.0
    @Published var categoryBreakdown: [(name: String, amount: Double, colorHex: String)] = []

    // modelContext used only for the category colour lookup — not for fetching transactions.
    private var modelContext: ModelContext?
    // Updated whenever SummaryView's @Query fires; recompute() reads from here.
    private var cachedTransactions: [Transaction] = []

    init() {}

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // Called by SummaryView whenever @Query delivers a new snapshot.
    func loadData(transactions: [Transaction]) {
        cachedTransactions = transactions
        recompute()
    }

    func goToPreviousMonth() {
        selectedMonth = DateHelpers.previousMonth(from: selectedMonth)
        recompute()
    }

    func goToNextMonth() {
        guard !isCurrentMonth else { return }
        selectedMonth = DateHelpers.nextMonth(from: selectedMonth)
        recompute()
    }

    var netBalance: Double { totalIncome - totalSpent }

    var monthLabel: String {
        DateHelpers.monthLabel(for: selectedMonth)
    }

    var isCurrentMonth: Bool {
        Calendar.current.isDate(selectedMonth, equalTo: Date.now, toGranularity: .month)
    }

    // MARK: - Private

    private func recompute() {
        let (rangeStart, rangeEnd) = DateHelpers.monthRange(for: selectedMonth)
        let monthly = cachedTransactions.filter { $0.date >= rangeStart && $0.date < rangeEnd }

        // All amounts are converted to CAD for chart totals.
        let cad = { (tx: Transaction) in tx.amount * tx.currency.cadConversionRate }

        totalIncome = monthly.filter(\.isIncome).reduce(0) { $0 + cad($1) }
        totalSpent  = monthly.filter { !$0.isIncome }.reduce(0) { $0 + cad($1) }

        var groups: [String: Double] = [:]
        for tx in monthly where !tx.isIncome {
            groups[tx.category, default: 0] += cad(tx)
        }
        let sorted = groups.sorted { $0.value > $1.value }

        let allCategories = (try? modelContext?.fetch(FetchDescriptor<Category>())) ?? []
        var colorMap: [String: String] = [:]
        for cat in allCategories { colorMap[cat.name] = cat.colorHex }

        categoryBreakdown = sorted.map { name, amount in
            (name: name, amount: amount, colorHex: colorMap[name] ?? "#C0BAB4")
        }
    }
}
