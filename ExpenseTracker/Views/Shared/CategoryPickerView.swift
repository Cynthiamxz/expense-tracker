// CategoryPickerView.swift
// Responsibility: Reusable category picker used in both TransactionDetailView (editing)
//                 and AddTransactionView (new transaction). Shows all categories with
//                 their colour dot in a menu. Binding-based — writes the selected
//                 category name back to the caller.
// Depends on: SwiftUI, SwiftData, Category model
// Used by: TransactionDetailView (category picker row), AddTransactionView (category field)

import SwiftUI
import SwiftData

struct CategoryPickerView: View {
    @Binding var selectedCategoryName: String
    @Query(sort: \Category.name) private var categories: [Category]

    var body: some View {
        Picker("Category", selection: $selectedCategoryName) {
            ForEach(categories, id: \.name) { category in
                HStack {
                    Circle()
                        .fill(Color(hex: category.colorHex))
                        .frame(width: 8, height: 8)
                    Text(category.name)
                }
                .tag(category.name)
            }
            // Fallback shown only when no categories are seeded yet.
            if categories.isEmpty {
                Text("Other").tag("Other")
            }
        }
    }
}

#Preview {
    @Previewable @State var selected = "Food & Dining"
    CategoryPickerView(selectedCategoryName: $selected)
        .modelContainer(for: Category.self, inMemory: true)
}
