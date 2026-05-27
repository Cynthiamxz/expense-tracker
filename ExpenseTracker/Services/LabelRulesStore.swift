// LabelRulesStore.swift
// Responsibility: Persistent store for Gmail label rules and their parsing templates.
//                 Serialises to UserDefaults so settings survive app restarts.
//                 Exposed as an @EnvironmentObject shared by SettingsView and SyncService.
// Depends on: Foundation, Constants, ParsingTemplate
// Used by: ExpenseTrackerApp (creates + injects), SyncService (reads enabledLabels +
//          allEnabledTemplates), SettingsView (displays + mutates rules)

import Foundation

// MARK: - Label rule

struct LabelRule: Identifiable, Codable {
    var id: UUID = UUID()
    var labelName: String
    var enabledTemplates: Set<ParsingTemplate>

    init(labelName: String, enabledTemplates: Set<ParsingTemplate> = [.default, .creditCardPurchase]) {
        self.labelName        = labelName
        self.enabledTemplates = enabledTemplates
    }

    // Custom decoder so rules saved before `enabledTemplates` existed still load.
    // Also tolerates old data that had an `isEnabled` field — extra keys are ignored.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decode(UUID.self,   forKey: .id)
        labelName        = try c.decode(String.self, forKey: .labelName)
        enabledTemplates = try c.decodeIfPresent(Set<ParsingTemplate>.self,
                                                 forKey: .enabledTemplates) ?? [.default, .creditCardPurchase]
    }
}

// MARK: - Store

class LabelRulesStore: ObservableObject {
    @Published var rules: [LabelRule] {
        didSet { persist() }
    }

    private static let key = "label_rules_v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([LabelRule].self, from: data) {
            rules = saved
            ensureCreditCardPurchaseTemplate()
        } else {
            rules = [LabelRule(labelName: Constants.Labels.defaultLabel)]
        }
    }

    // One-time migration: rules stored before .creditCardPurchase existed only have
    // [.default]. Add .creditCardPurchase to every rule that's missing it.
    private func ensureCreditCardPurchaseTemplate() {
        var changed = false
        for idx in rules.indices where !rules[idx].enabledTemplates.contains(.creditCardPurchase) {
            rules[idx].enabledTemplates.insert(.creditCardPurchase)
            changed = true
        }
        if changed { persist() }
    }

    /// Label names queried during sync — all rules.
    var enabledLabels: [String] {
        let names = rules.map(\.labelName)
        return names.isEmpty ? [Constants.Labels.defaultLabel] : names
    }

    /// Union of all parsing templates enabled across all rules.
    var allEnabledTemplates: Set<ParsingTemplate> {
        Set(rules.flatMap(\.enabledTemplates))
    }

    func update(_ rule: LabelRule) {
        guard let idx = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[idx] = rule
    }

    // The default cibc-transactions rule is protected from deletion.
    func delete(_ rule: LabelRule) {
        guard rule.labelName != Constants.Labels.defaultLabel else { return }
        rules.removeAll { $0.id == rule.id }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
