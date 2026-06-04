// AddTransactionView.swift
// Responsibility: Sheet for manually entering a transaction. All fields default per
//                 spec. On save, inserts a Transaction with isManual=true and
//                 gmailMessageId=nil. Presented from the "+" FAB in TransactionsView.
// Depends on: Transaction model, CategoryPickerView, Constants
// Used by: TransactionsView (.sheet(isPresented: $showAddSheet))

import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var description: String = ""
    @State private var amountText: String = ""
    @State private var date: Date = Date()
    @State private var selectedCategory: String = "Other"
    @State private var selectedCurrency: Currency = .cad

    private var parsedAmount: Double? {
        Double(amountText
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: ""))
    }

    private var canSave: Bool {
        !description.trimmingCharacters(in: .whitespaces).isEmpty
            && (parsedAmount ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Transaction") {
                    TextField("Description", text: $description)
                    TextField("Amount (e.g. 42.99)", text: $amountText)
                        .keyboardType(.decimalPad)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Picker("Currency", selection: $selectedCurrency) {
                        ForEach(Currency.allCases, id: \.self) { c in
                            Text(c.code).tag(c)
                        }
                    }
                }

                Section("Category") {
                    CategoryPickerView(selectedCategoryName: $selectedCategory)
                }

                Section {
                    Button("Save transaction") {
                        saveTransaction()
                    }
                    .disabled(!canSave)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(canSave ? .white : Color(hex: Constants.Design.mutedText))
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(canSave
                                  ? Color(hex: Constants.Design.primaryText)
                                  : Color(hex: Constants.Design.surface))
                    )
                }
            }
            .navigationTitle("Add Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func saveTransaction() {
        guard let amount = parsedAmount, amount > 0 else { return }
        let tx = Transaction(
            date:        date,
            amount:      amount,
            description: description.trimmingCharacters(in: .whitespaces),
            category:    selectedCategory,
            account:     .other,
            currency:    selectedCurrency,
            isManual:    true
        )
        modelContext.insert(tx)
        dismiss()
    }
}

#Preview {
    AddTransactionView()
        .modelContainer(for: [Transaction.self, Category.self], inMemory: true)
}
