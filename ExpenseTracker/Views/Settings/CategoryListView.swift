// CategoryListView.swift
// Responsibility: Displays all categories (built-in + custom) with their colour dot
//                 and name. Allows the user to add a new custom category. Built-in
//                 categories (isCustom == false) cannot be deleted; custom ones can.
// Depends on: SwiftData, Category model, Constants
// Used by: SettingsView (NavigationLink → CategoryListView)

import SwiftUI
import SwiftData

struct CategoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.name) private var categories: [Category]

    @State private var showAddSheet: Bool = false
    @State private var newCategoryName: String = ""

    var body: some View {
        List {
            ForEach(categories) { category in
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color(hex: category.colorHex))
                        .frame(width: 10, height: 10)
                    Text(category.name)
                    Spacer()
                    if !category.isCustom {
                        Text("Default")
                            .font(.caption)
                            .foregroundStyle(Color(hex: Constants.Design.mutedText))
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if category.isCustom {
                        Button(role: .destructive) {
                            modelContext.delete(category)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            Button {
                showAddSheet = true
            } label: {
                Label("Add custom category", systemImage: "plus")
            }
        }
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddSheet) {
            addCategorySheet
        }
    }

    private var addCategorySheet: some View {
        NavigationStack {
            Form {
                TextField("Category name", text: $newCategoryName)
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        newCategoryName = ""
                        showAddSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addCategory()
                        showAddSheet = false
                    }
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func addCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let palette = Constants.DefaultCategories.all.map(\.colorHex)
        let usedColors = Set(categories.map(\.colorHex))
        let chosenColor = palette.first { !usedColors.contains($0) }
            ?? palette[categories.count % palette.count]

        modelContext.insert(Category(name: name, colorHex: chosenColor, isCustom: true))
        newCategoryName = ""
    }
}

#Preview {
    NavigationStack {
        CategoryListView()
            .modelContainer(for: Category.self, inMemory: true)
    }
}
