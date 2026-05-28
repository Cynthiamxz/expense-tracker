// SettingsView.swift
// Responsibility: Tab 3 root view — Gmail account connection, Gmail label rules,
//                 and category management. All content is expanded inline on one
//                 page using the same surface-card style as SummaryView.
// Depends on: GmailAuthService, LabelRulesStore, Category model, Constants
// Used by: ContentView (Tab 2)

import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject private var authService: GmailAuthService
    @EnvironmentObject private var labelRulesStore: LabelRulesStore
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.name) private var categories: [Category]

    @State private var showDisconnectDialog  = false
    @State private var showAddRuleSheet      = false
    @State private var showAddCategorySheet  = false
    @State private var ruleToEdit: LabelRule?    = nil
    @State private var ruleToDelete: LabelRule?  = nil
    @State private var categoryToDelete: Category? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    gmailAccountCard
                    labelRulesCard
                    categoriesCard

                    Text("Expense Tracker v1.1")
                        .font(.caption.monospaced())
                        .foregroundStyle(Color(hex: Constants.Design.mutedText))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(hex: Constants.Design.background))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showAddRuleSheet) {
            AddLabelRuleSheet { rule in
                labelRulesStore.rules.append(rule)
            }
        }
        .sheet(item: $ruleToEdit) { rule in
            let isProtected = rule.labelName == Constants.Labels.defaultLabel
            EditLabelRuleSheet(
                rule: rule,
                onSave: { updated in labelRulesStore.update(updated) },
                onDelete: isProtected ? nil : { labelRulesStore.delete(rule) }
            )
        }
        .sheet(isPresented: $showAddCategorySheet) {
            AddCategorySheet(existingColors: categories.map(\.colorHex)) { name, colorHex in
                modelContext.insert(Category(name: name, colorHex: colorHex, isCustom: true))
            }
        }
    }

    // MARK: - Section header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.monospaced())
            .foregroundStyle(Color(hex: Constants.Design.secondaryText))
            .padding(.leading, 4)
    }

    // MARK: - Gmail account card

    private var gmailAccountCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("GMAIL ACCOUNT")

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: Constants.Design.spentRedBg))
                            .frame(width: 36, height: 36)
                        Image(systemName: "envelope.fill")
                            .font(.body)
                            .foregroundStyle(Color(hex: Constants.Design.spentRedText))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        if authService.isAuthenticated, let email = authService.connectedEmail {
                            Text(email)
                                .font(.body)
                                .foregroundStyle(Color(hex: Constants.Design.primaryText))
                            Text("connected")
                                .font(.caption)
                                .foregroundStyle(Color(hex: Constants.Design.secondaryText))
                        } else if authService.isLoading {
                            Text("Signing in…")
                                .font(.body)
                                .foregroundStyle(Color(hex: Constants.Design.primaryText))
                        } else {
                            Text("Connect Gmail Account")
                                .font(.body)
                                .foregroundStyle(Color(hex: Constants.Design.primaryText))
                        }
                    }

                    Spacer()

                    if authService.isLoading {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: authService.isAuthenticated ? "chevron.right" : "arrow.right.circle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(hex: Constants.Design.mutedText))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
                .onTapGesture {
                    if authService.isAuthenticated {
                        showDisconnectDialog = true
                    } else {
                        Task {
                            do { try await authService.signIn() }
                            catch { authService.errorMessage = error.localizedDescription }
                        }
                    }
                }
                .confirmationDialog(
                    "Disconnect Gmail?",
                    isPresented: $showDisconnectDialog,
                    titleVisibility: .visible
                ) {
                    Button("Disconnect", role: .destructive) { authService.signOut() }
                } message: {
                    Text("Existing transactions are kept. You can reconnect at any time.")
                }

                if let error = authService.errorMessage {
                    Divider().padding(.leading, 16)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Color(hex: Constants.Design.deleteRedText))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
            }
            .background(Color(hex: Constants.Design.surface))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Label rules card

    private var labelRulesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("GMAIL LABEL RULES")

            VStack(spacing: 0) {
                ForEach(labelRulesStore.rules.indices, id: \.self) { idx in
                    let rule = labelRulesStore.rules[idx]
                    let isDefault = rule.labelName == Constants.Labels.defaultLabel

                    Group {
                        if isDefault {
                            ruleRow(idx: idx)
                        } else {
                            SwipeToDeleteRow {
                                ruleRow(idx: idx)
                            } onDelete: {
                                ruleToDelete = rule
                            }
                        }
                    }

                    if idx < labelRulesStore.rules.count - 1 {
                        Divider().padding(.leading, 16)
                    }
                }

                Divider().padding(.leading, 16)

                Button {
                    showAddRuleSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus").font(.body.weight(.medium))
                        Text("Add label rule").font(.body)
                    }
                    .foregroundStyle(Color(hex: Constants.Design.primaryText))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .background(Color(hex: Constants.Design.surface))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .confirmationDialog(
                "Delete \"\(ruleToDelete?.labelName ?? "")\"?",
                isPresented: Binding(
                    get: { ruleToDelete != nil },
                    set: { if !$0 { ruleToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let rule = ruleToDelete { labelRulesStore.delete(rule) }
                    ruleToDelete = nil
                }
            } message: {
                Text("This label will no longer be synced.")
            }
        }
    }

    // A single label rule row: taps open the edit sheet.
    private func ruleRow(idx: Int) -> some View {
        Button {
            ruleToEdit = labelRulesStore.rules[idx]
        } label: {
            HStack(spacing: 12) {
                Text(labelRulesStore.rules[idx].labelName)
                    .font(.body)
                    .foregroundStyle(Color(hex: Constants.Design.primaryText))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(hex: Constants.Design.mutedText))
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: Constants.Design.surface))
    }

    // MARK: - Categories card

    private var categoriesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("CATEGORIES")

            VStack(spacing: 0) {
                ForEach(categories) { category in
                    if category.isCustom {
                        SwipeToDeleteRow {
                            categoryRow(category)
                        } onDelete: {
                            categoryToDelete = category
                        }
                    } else {
                        categoryRow(category)
                    }

                    if category.id != categories.last?.id {
                        Divider().padding(.leading, 38)
                    }
                }

                Divider().padding(.leading, 16)

                Button {
                    showAddCategorySheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus").font(.body.weight(.medium))
                        Text("Add custom category").font(.body)
                    }
                    .foregroundStyle(Color(hex: Constants.Design.primaryText))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .background(Color(hex: Constants.Design.surface))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .confirmationDialog(
                "Delete \"\(categoryToDelete?.name ?? "")\"?",
                isPresented: Binding(
                    get: { categoryToDelete != nil },
                    set: { if !$0 { categoryToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let cat = categoryToDelete { modelContext.delete(cat) }
                    categoryToDelete = nil
                }
                Button("Cancel", role: .cancel) { categoryToDelete = nil }
            } message: {
                Text("Existing transactions will keep their assigned category name.")
            }
        }
    }

    private func categoryRow(_ category: Category) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: category.colorHex))
                .frame(width: 10, height: 10)
            Text(category.name)
                .font(.body)
                .foregroundStyle(Color(hex: Constants.Design.primaryText))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: Constants.Design.surface))
    }
}

// MARK: - Swipe-to-delete row wrapper

private struct SwipeToDeleteRow<Content: View>: View {
    @ViewBuilder let content: () -> Content
    let onDelete: () -> Void

    private let revealWidth: CGFloat = 72
    @State private var offset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .trailing) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { offset = 0 }
                onDelete()
            } label: {
                Text("Delete")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(minWidth: revealWidth, maxWidth: revealWidth, maxHeight: .infinity)
                    .background(Color(hex: Constants.Design.deleteRedText))
            }

            content()
                .offset(x: offset)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 15, coordinateSpace: .local)
                        .onChanged { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            let drag = value.translation.width
                            if drag < 0 {
                                offset = max(drag, -revealWidth)
                            } else if offset < 0 {
                                offset = min(0, offset + drag)
                            }
                        }
                        .onEnded { value in
                            withAnimation(.easeOut(duration: 0.25)) {
                                offset = value.translation.width < -(revealWidth / 2) ? -revealWidth : 0
                            }
                        }
                )
        }
        .clipped()
    }
}

// MARK: - Add label rule sheet

private struct AddLabelRuleSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (LabelRule) -> Void

    @State private var labelName = ""
    private var canAdd: Bool { !labelName.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Gmail Label") {
                    TextField("e.g. cibc-credit", text: $labelName)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("Add Label Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(LabelRule(
                            labelName: labelName.trimmingCharacters(in: .whitespaces)
                        ))
                        dismiss()
                    }
                    .disabled(!canAdd)
                }
            }
        }
    }
}

// MARK: - Edit label rule sheet

private struct EditLabelRuleSheet: View {
    @Environment(\.dismiss) private var dismiss
    let rule: LabelRule
    let onSave: (LabelRule) -> Void
    let onDelete: (() -> Void)?  // nil for the protected default rule

    @State private var labelName: String
    @State private var enabledTemplates: Set<ParsingTemplate>
    @State private var showDeleteConfirm = false

    private var isDefault: Bool { rule.labelName == Constants.Labels.defaultLabel }
    private var canSave: Bool { !labelName.trimmingCharacters(in: .whitespaces).isEmpty }

    init(rule: LabelRule, onSave: @escaping (LabelRule) -> Void, onDelete: (() -> Void)? = nil) {
        self.rule     = rule
        self.onSave   = onSave
        self.onDelete = onDelete
        _labelName        = State(initialValue: rule.labelName)
        _enabledTemplates = State(initialValue: rule.enabledTemplates)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Gmail Label Name") {
                    TextField("Label name", text: $labelName)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .disabled(isDefault)
                        .foregroundStyle(isDefault
                            ? Color(hex: Constants.Design.secondaryText)
                            : Color(hex: Constants.Design.primaryText))
                }

                Section("Parsing Templates") {
                    ForEach(ParsingTemplate.allCases, id: \.self) { template in
                        VStack(alignment: .leading, spacing: 2) {
                            Toggle(template.displayName, isOn: Binding(
                                get: { enabledTemplates.contains(template) },
                                set: { on in
                                    if on { enabledTemplates.insert(template) }
                                    else  { enabledTemplates.remove(template) }
                                }
                            ))
                            Text(template.detail)
                                .font(.caption)
                                .foregroundStyle(Color(hex: Constants.Design.secondaryText))
                        }
                        .padding(.vertical, 2)
                    }
                }

                if let onDelete {
                    Section {
                        Button("Delete Rule", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }
                    .confirmationDialog(
                        "Delete \"\(rule.labelName)\"?",
                        isPresented: $showDeleteConfirm,
                        titleVisibility: .visible
                    ) {
                        Button("Delete", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    } message: {
                        Text("This label will no longer be synced.")
                    }
                }

                if isDefault {
                    Section {
                        Text("The built-in label name cannot be changed.")
                            .font(.caption)
                            .foregroundStyle(Color(hex: Constants.Design.secondaryText))
                    }
                }
            }
            .navigationTitle("Edit Label Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = rule
                        updated.labelName = isDefault
                            ? rule.labelName
                            : labelName.trimmingCharacters(in: .whitespaces)
                        updated.enabledTemplates = enabledTemplates
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

// MARK: - Add category sheet

private struct AddCategorySheet: View {
    @Environment(\.dismiss) private var dismiss

    let existingColors: [String]
    let onAdd: (String, String) -> Void

    @State private var name = ""
    private var canAdd: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    private var chosenColor: String {
        let palette = Constants.DefaultCategories.all.map(\.colorHex)
        let used = Set(existingColors)
        return palette.first { !used.contains($0) } ?? palette[existingColors.count % palette.count]
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Category name", text: $name)
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(name.trimmingCharacters(in: .whitespaces), chosenColor)
                        dismiss()
                    }
                    .disabled(!canAdd)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(GmailAuthService())
        .environmentObject(LabelRulesStore())
        .modelContainer(for: [Transaction.self, Category.self], inMemory: true)
}
