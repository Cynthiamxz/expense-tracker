// CreditCardPurchaseTemplate.swift
// Responsibility: Parsing strategy for CIBC "New purchase on your credit card" alerts.
//                 Extracts amount and description using the specific email pattern:
//                 "for $X.XX at MERCHANT_NAME."
// Depends on: EmailParserService (extends it), Transaction model
// Used by: EmailParserService.parse() when .creditCardPurchase template is enabled

import Foundation

extension EmailParserService {

    func parseCreditCardPurchase(
        _ body: String, subject: String, messageId: String, fallbackDate: Date?
    ) -> Transaction? {
        guard subject.lowercased().contains("new purchase on your credit card") else { return nil }

        guard let amount = extractAmount(from: body) else {
            print("[Parser] ❌ No amount found (creditCardPurchase) in \(messageId)")
            return nil
        }

        let merchantPattern = #"(?i)for\s+\$[0-9,]+\.[0-9]{2}\s+at\s+([^.]+)"#
        let description = extractText(from: body, pattern: merchantPattern)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? subject
        let date     = extractDate(from: body, fallbackDate: fallbackDate) ?? Date.now
        let currency = detectCurrency(from: body)
        let category = detectCategory(from: description, body: body)

        return Transaction(
            date:           date,
            amount:         amount,
            description:    description,
            category:       category,
            account:        .creditCard,
            currency:       currency,
            isManual:       false,
            gmailMessageId: messageId
        )
    }
}
