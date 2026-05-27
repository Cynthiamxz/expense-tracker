// Category.swift
// Responsibility: SwiftData model for a spending category. Stores both the
//                 built-in default categories (seeded once on first launch) and
//                 any user-created custom ones. Also provides the seeding helper
//                 called from ExpenseTrackerApp.
// Depends on: SwiftData, Foundation, Constants (for seed data)
// Used by: ExpenseTrackerApp (first-launch seeding), CategoryPickerView,
//          CategoryListView, SummaryViewModel (aggregation), TransactionDetailView

import Foundation
import SwiftData

@Model
final class Category {
    var id: UUID
    var name: String
    // Hex string e.g. "#C4A882" — rendered as a colour dot throughout the UI.
    var colorHex: String
    // false = built-in (cannot be deleted by the user), true = user-created.
    var isCustom: Bool

    init(id: UUID = UUID(), name: String, colorHex: String, isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.isCustom = isCustom
    }

    static func seedDefaults(into modelContext: ModelContext) {
        for (name, colorHex) in Constants.DefaultCategories.all {
            modelContext.insert(Category(name: name, colorHex: colorHex, isCustom: false))
        }
        try? modelContext.save()
    }
}
