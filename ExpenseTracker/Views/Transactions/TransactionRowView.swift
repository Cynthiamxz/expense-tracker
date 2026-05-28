// TransactionRowView.swift
// Responsibility: Single transaction row inside a date group — shows category colour
//                 dot, transaction description, and the formatted amount. Income
//                 transactions show the amount in green; all others in primary text.
// Depends on: Transaction model, Category model (for dot colour lookup), Constants
// Used by: DateGroupView (one per Transaction in a section)

import SwiftUI
import SwiftData

struct TransactionRowView: View {
    let transaction: Transaction
    @Query private var categories: [Category]

    var dotColor: Color {
        categories.first(where: { $0.name == transaction.category })
            .map { Color(hex: $0.colorHex) }
            ?? Color(hex: Constants.Design.mutedText)
    }

    var amountColor: Color {
        transaction.isIncome
            ? Color(hex: Constants.Design.incomeGreenText)
            : Color(hex: Constants.Design.primaryText)
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)

            Text(transaction.displayName)
                .font(.body)
                .foregroundStyle(Color(hex: Constants.Design.primaryText))
                .lineLimit(1)

            Spacer()

            Text("\(transaction.currency.symbol)\(transaction.amount, format: .number.precision(.fractionLength(2)))")
                .font(.body.monospaced())
                .foregroundStyle(amountColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(hex: Constants.Design.background))
    }
}

#Preview {
    let tx = Transaction(date: Date(), amount: 42.99, description: "Tim Hortons",
                         account: .chequing, type: .debit, isManual: false)
    TransactionRowView(transaction: tx)
        .modelContainer(for: [Transaction.self, Category.self], inMemory: true)
}
