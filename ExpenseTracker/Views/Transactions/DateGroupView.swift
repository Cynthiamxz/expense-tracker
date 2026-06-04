// DateGroupView.swift
// Responsibility: A single date-grouped section in the Transactions list — renders
//                 the warm-tan date band header and then all TransactionRowViews for
//                 that day. Used as a subview inside TransactionsView's List.
// Depends on: TransactionRowView, Transaction model, Constants (design tokens)
// Used by: TransactionsView (one DateGroupView per section in groupedTransactions)

import SwiftUI

struct DateGroupView: View {
    let header: String
    let transactions: [Transaction]
    let onSelect: (Transaction) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Date band header
            HStack {
                Text(header)
                    .font(.caption.monospaced())
                    .foregroundStyle(Color(hex: Constants.Design.secondaryText))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                Spacer()
            }
            .background(Color(hex: Constants.Design.dateBand))

            // Transaction rows with inter-row dividers (no trailing divider after last row)
            ForEach(Array(transactions.enumerated()), id: \.element.id) { index, tx in
                TransactionRowView(transaction: tx)
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(tx) }
                if index < transactions.count - 1 {
                    Divider()
                        .background(Color(hex: Constants.Design.dateBandBorder))
                        .padding(.leading, 30)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: Constants.Design.dateBandBorder), lineWidth: 0.5)
        )
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowBackground(Color.clear)
    }
}

#Preview {
    let tx1 = Transaction(date: Date(), amount: 42.99, description: "Tim Hortons",
                          account: .chequing, isManual: false)
    let tx2 = Transaction(date: Date(), amount: 12.50, description: "Uber",
                          account: .creditCard, isManual: false)
    List {
        DateGroupView(header: "MAY 24", transactions: [tx1, tx2], onSelect: { _ in })
    }
    .listStyle(.plain)
    .modelContainer(for: [Transaction.self, Category.self], inMemory: true)
}
