// SummaryView.swift
// Responsibility: Tab 1 root view — month navigation chevrons, the hero "TOTAL SPENT"
//                 surface card (with income/spent pills), and the category donut chart
//                 surface card. Delegates data to SummaryViewModel.
// Depends on: SummaryViewModel, DonutChartView, CategoryLegendView, Constants
// Used by: ContentView (Tab 0)

import SwiftUI
import SwiftData

struct SummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = SummaryViewModel()
    // @Query gives us a live SwiftData view — it fires whenever transactions change,
    // letting the chart stay in sync without manual polling.
    @Query private var transactions: [Transaction]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                monthSelector
                heroBlock
                chartBlock
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(Color(hex: Constants.Design.background))
        .task {
            viewModel.configure(modelContext: modelContext)
            viewModel.loadData(transactions: transactions)
        }
        .onChange(of: transactions) { _, newTransactions in
            viewModel.loadData(transactions: newTransactions)
        }
    }

    // MARK: - Month selector

    private var monthSelector: some View {
        HStack {
            Button {
                viewModel.goToPreviousMonth()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(hex: Constants.Design.primaryText))
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text(viewModel.monthLabel)
                .font(.headline)
                .foregroundStyle(Color(hex: Constants.Design.primaryText))

            Spacer()

            Button {
                viewModel.goToNextMonth()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(
                        viewModel.isCurrentMonth
                            ? Color(hex: Constants.Design.mutedText)
                            : Color(hex: Constants.Design.primaryText)
                    )
                    .frame(width: 44, height: 44)
            }
            .disabled(viewModel.isCurrentMonth)
        }
    }

    // MARK: - Hero block

    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TOTAL BALANCE")
                .font(.caption.monospaced())
                .foregroundStyle(Color(hex: Constants.Design.secondaryText))

            Text(viewModel.netBalance, format: .currency(code: "CAD").presentation(.narrow))
                .font(.system(size: 42, weight: .semibold, design: .serif))
                .foregroundStyle(Color(hex: Constants.Design.primaryText))
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            HStack(spacing: 8) {
                StatPill(
                    direction: "arrow.up",
                    amount: viewModel.totalIncome,
                    bgHex: Constants.Design.incomeGreenBg,
                    fgHex: Constants.Design.incomeGreenText
                )
                StatPill(
                    direction: "arrow.down",
                    amount: viewModel.totalSpent,
                    bgHex: Constants.Design.spentRedBg,
                    fgHex: Constants.Design.spentRedText
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: Constants.Design.surface))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Chart block

    private var chartBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SPENDING BY CATEGORY")
                .font(.caption.monospaced())
                .foregroundStyle(Color(hex: Constants.Design.secondaryText))

            if viewModel.categoryBreakdown.isEmpty {
                Text("No transactions this month")
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: Constants.Design.mutedText))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                DonutChartView(breakdown: viewModel.categoryBreakdown)
                    .frame(width: 220, height: 220)
                    .frame(maxWidth: .infinity)

                Divider()
                    .padding(.vertical, 4)

                CategoryLegendView(breakdown: viewModel.categoryBreakdown)
            }
        }
        .padding(20)
        .background(Color(hex: Constants.Design.surface))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Stat pill

private struct StatPill: View {
    let direction: String
    let amount: Double
    let bgHex: String
    let fgHex: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: direction)
                .font(.caption2.weight(.bold))
            Text(amount, format: .currency(code: "CAD").presentation(.narrow))
                .font(.caption.bold())
                .lineLimit(1)
        }
        .foregroundStyle(Color(hex: fgHex))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(hex: bgHex))
        .clipShape(Capsule())
    }
}

#Preview {
    SummaryView()
        .modelContainer(for: [Transaction.self, Category.self], inMemory: true)
}
