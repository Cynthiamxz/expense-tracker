// DefaultTemplate.swift
// Responsibility: "Default" parsing strategy — classifies account type (chequing vs
//                 credit card) and transaction direction using keyword matching.
// Depends on: EmailParserService (extends it), Transaction model
// Used by: EmailParserService.parse() when .default template is enabled

import Foundation

extension EmailParserService {

    func parseDefault(
        _ body: String, subject: String, messageId: String, fallbackDate: Date?
    ) -> Transaction? {
        let combined = (subject + " " + body).lowercased()

        if creditCardKeywords.contains(where: { combined.contains($0) }) {
            return parseCreditCardDefault(body, subject: subject,
                                          messageId: messageId, fallbackDate: fallbackDate)
        }
        if chequingKeywords.contains(where: { combined.contains($0) }) {
            return parseChequingDefault(body, subject: subject,
                                        messageId: messageId, fallbackDate: fallbackDate)
        }

        print("[Parser] ⚠️  No account-type keyword matched in message \(messageId) — subject: \(subject)")
        return nil
    }

    private func parseChequingDefault(
        _ body: String, subject: String, messageId: String, fallbackDate: Date?
    ) -> Transaction? {
        guard let amount = extractAmount(from: body) else {
            print("[Parser] ❌ No amount found (chequing) in \(messageId)")
            return nil
        }
        let description = extractMerchant(from: body) ?? subject
        let date        = extractDate(from: body, fallbackDate: fallbackDate) ?? Date.now
        let type        = determineTxType(subject: subject, body: body, account: .chequing)
        let currency    = detectCurrency(from: body)
        let category    = detectCategory(from: description, body: body)
        return Transaction(
            date: date, amount: amount,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category, account: .chequing, type: type, currency: currency,
            isManual: false, gmailMessageId: messageId
        )
    }

    private func parseCreditCardDefault(
        _ body: String, subject: String, messageId: String, fallbackDate: Date?
    ) -> Transaction? {
        guard let amount = extractAmount(from: body) else {
            print("[Parser] ❌ No amount found (credit card) in \(messageId)")
            return nil
        }
        let description = extractMerchant(from: body) ?? subject
        let date        = extractDate(from: body, fallbackDate: fallbackDate) ?? Date.now
        let type        = determineTxType(subject: subject, body: body, account: .creditCard)
        let currency    = detectCurrency(from: body)
        let category    = detectCategory(from: description, body: body)
        return Transaction(
            date: date, amount: amount,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category, account: .creditCard, type: type, currency: currency,
            isManual: false, gmailMessageId: messageId
        )
    }

    func extractMerchant(from body: String) -> String? {
        for pattern in merchantPatterns {
            if let match = extractText(from: body, pattern: pattern) {
                let cleaned = match.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty { return cleaned }
            }
        }
        return nil
    }

    func determineTxType(subject: String, body: String, account: Account) -> TxType {
        let combined = (subject + " " + body).lowercased()
        if eTransferKeywords.contains(where: { combined.contains($0) }) { return .eTransfer }
        if refundKeywords.contains(where:    { combined.contains($0) }) { return .refund    }
        if debitKeywords.contains(where:     { combined.contains($0) }) { return .debit     }
        return .credit
    }
}
