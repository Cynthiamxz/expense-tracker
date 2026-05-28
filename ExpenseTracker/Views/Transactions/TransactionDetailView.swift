// TransactionDetailView.swift
// Responsibility: Bottom sheet presented when the user taps a transaction row.
//                 Read-only fields are displayed as plain text. Editable fields
//                 (display name, category, type) allow in-place editing that persists
//                 to SwiftData on Done. Also provides delete-with-confirmation.
// Depends on: Transaction model, CategoryPickerView, Constants
// Used by: TransactionsView (.sheet(item: $selectedTransaction))

import SwiftUI
import SwiftData

struct TransactionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let transaction: Transaction
    let onDelete: () -> Void

    @State private var displayName: String
    @State private var selectedCategory: String
    @State private var selectedType: TxType
    @State private var selectedCurrency: Currency
    @State private var showDeleteConfirmation: Bool = false

    init(transaction: Transaction, onDelete: @escaping () -> Void) {
        self.transaction = transaction
        self.onDelete = onDelete
        _displayName      = State(initialValue: transaction.descriptionClean ?? "")
        _selectedCategory = State(initialValue: transaction.category)
        _selectedType     = State(initialValue: transaction.type)
        _selectedCurrency = State(initialValue: transaction.currency)
    }

    var body: some View {
        NavigationStack {
            Form {
                readOnlySection
                editableSection
                deleteSection
            }
            .navigationTitle("Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveChanges()
                        dismiss()
                    }
                    .foregroundStyle(Color(hex: Constants.Design.primaryText))
                }
            }
            .confirmationDialog(
                "Delete this transaction?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Sections

    private var readOnlySection: some View {
        Section("Details") {
            LabeledContent("Amount") {
                Text("\(transaction.currency.symbol)\(transaction.amount, format: .number.precision(.fractionLength(2)))")
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Date") {
                Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Account") {
                Text(transaction.account.displayName)
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Description") {
                Text(transaction.rawDescription)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if let gmailId = transaction.gmailMessageId {
                LabeledContent("Gmail ID") {
                    Text(gmailId)
                        .foregroundStyle(.secondary)
                        .font(.caption.monospaced())
                        .lineLimit(1)
                }
            }
        }
    }

    private var editableSection: some View {
        Section("Edit") {
            TextField("Set display name…", text: $displayName)
            CategoryPickerView(selectedCategoryName: $selectedCategory)
            Picker("Type", selection: $selectedType) {
                ForEach(TxType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            Picker("Currency", selection: $selectedCurrency) {
                ForEach(Currency.allCases, id: \.self) { c in
                    Text(c.code).tag(c)
                }
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button("Delete transaction") {
                showDeleteConfirmation = true
            }
            .foregroundStyle(Color(hex: Constants.Design.deleteRedText))
        }
    }

    // MARK: - Save

    private func saveChanges() {
        transaction.descriptionClean = displayName.isEmpty ? nil : displayName
        transaction.category         = selectedCategory
        transaction.type             = selectedType
        transaction.currency         = selectedCurrency
    }
}

#Preview {
    let tx = Transaction(date: Date(), amount: 42.99, description: "Tim Hortons",
                         account: .chequing, type: .debit, isManual: false)
    TransactionDetailView(transaction: tx, onDelete: {})
        .modelContainer(for: [Transaction.self, Category.self], inMemory: true)
}
