// Transaction.swift
// Responsibility: SwiftData model for a single financial transaction — both
//                 Gmail-imported and manually entered. Also owns the Account
//                 and TxType enums that classify each transaction.
// Depends on: SwiftData, Foundation
// Used by: ExpenseTrackerApp (schema registration), SyncService (insert),
//          TransactionsViewModel (query + grouping), SummaryViewModel (aggregation),
//          TransactionDetailView (read + edit), AddTransactionView (create)

import Foundation
import SwiftData

// Stored on Transaction.account — identifies which account the transaction belongs to.
enum Account: String, Codable, CaseIterable {
    case chequing
    case creditCard
    case cash
    case other

    var displayName: String {
        switch self {
        case .chequing:   return "Chequing"
        case .creditCard: return "Credit Card"
        case .cash:       return "Cash"
        case .other:      return "Other"
        }
    }
}

// Stored on Transaction.type — classifies the financial direction of a transaction.
enum TxType: String, Codable, CaseIterable {
    case debit
    case credit
    case refund
    case eTransfer

    var displayName: String {
        switch self {
        case .debit:     return "Debit"
        case .credit:    return "Credit"
        case .refund:    return "Refund"
        case .eTransfer: return "e-Transfer"
        }
    }
}

enum Currency: String, Codable, CaseIterable {
    case cad = "CAD"
    case usd = "USD"

    var code: String { rawValue }

    var displayName: String {
        switch self {
        case .cad: return "Canadian Dollar (CAD)"
        case .usd: return "US Dollar (USD)"
        }
    }
}

@Model
final class Transaction {
    var id: UUID
    var date: Date
    // Always a positive CAD value. Sign is conveyed by `type` (debit vs credit).
    var amount: Double
    // Raw description string from the CIBC email — never modified after import.
    var rawDescription: String
    // User-set display name override. nil means show `rawDescription` in the UI.
    var descriptionClean: String?
    // Category name string (matches Category.name). Defaults to "Other" on import.
    var category: String
    var account: Account
    var type: TxType
    // Stored as a String so the @Model macro accepts the "CAD" literal default,
    // which SwiftData uses as the column default during lightweight migration.
    var currencyCode: String = "CAD"
    // true for user-entered transactions (AddTransactionView); false for Gmail-imported ones.
    var isManual: Bool
    // Gmail REST API message ID — used for deduplication. nil for manual entries.
    var gmailMessageId: String?

    // Computed — not stored — so the @Model macro leaves it alone.
    var currency: Currency {
        get { Currency(rawValue: currencyCode) ?? .cad }
        set { currencyCode = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        date: Date,
        amount: Double,
        description: String,
        descriptionClean: String? = nil,
        category: String = "Other",
        account: Account,
        type: TxType,
        currency: Currency = .cad,
        isManual: Bool,
        gmailMessageId: String? = nil
    ) {
        self.id = id
        self.date = date
        self.amount = amount
        self.rawDescription = description
        self.descriptionClean = descriptionClean
        self.category = category
        self.account = account
        self.type = type
        self.currencyCode = currency.rawValue
        self.isManual = isManual
        self.gmailMessageId = gmailMessageId
    }

    // The name shown in list rows — prefer the user-set clean name when available.
    var displayName: String {
        descriptionClean ?? rawDescription
    }

    // Returns true when the category is an income category.
    // The set of income categories is defined in Constants.Categories.incomeNames.
    var isIncome: Bool {
        Constants.Categories.incomeNames.contains(category)
    }
}
