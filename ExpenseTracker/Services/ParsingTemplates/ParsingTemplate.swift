// ParsingTemplate.swift
// Responsibility: Catalogue of email parsing strategies that can be toggled per label rule.
//                 Stored in LabelRule.enabledTemplates via Codable.
// Depends on: Foundation
// Used by: LabelRulesStore, EmailParserService, SettingsView (EditLabelRuleSheet)

import Foundation

enum ParsingTemplate: String, Codable, CaseIterable {
    case `default`          = "default"
    case creditCardPurchase = "credit_card_purchase"

    var displayName: String {
        switch self {
        case .default:             return "Default"
        case .creditCardPurchase:  return "Credit Card Purchase"
        }
    }

    // Short description shown below the toggle in the edit sheet.
    var detail: String {
        switch self {
        case .default:
            return "Keyword-based account + direction detection"
        case .creditCardPurchase:
            return "Subject: \"New purchase on your credit card\""
        }
    }
}
