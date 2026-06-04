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
        if eTransferKeywords.contains(where: { combined.contains($0) }) {
            return parseETransferDefault(body, subject: subject,
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
        let currency    = detectCurrency(from: body)
        let category    = detectCategory(from: description, body: body)
        return Transaction(
            date: date, amount: amount,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category, account: .chequing, currency: currency,
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
        let currency    = detectCurrency(from: body)
        let category    = detectCategory(from: description, body: body)
        return Transaction(
            date: date, amount: amount,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category, account: .creditCard, currency: currency,
            isManual: false, gmailMessageId: messageId
        )
    }

    private func parseETransferDefault(
        _ body: String, subject: String, messageId: String, fallbackDate: Date?
    ) -> Transaction? {
        guard let amount = extractAmount(from: body) else {
            print("[Parser] ❌ No amount found (e-transfer) in \(messageId)")
            return nil
        }
        // After HTML stripping the body is one long line, so stop the name capture
        // before the next field label (any word(s) followed by a colon).
        let namePattern  = #"(?i)contact name\s*:\s*(.+?)(?=\s+\w[\w ]*:)"#
        // Email addresses contain no spaces, so \S+ captures exactly the address.
        let emailPattern = #"(?i)contact email address\s*:\s*(\S+)"#
        let contactName  = extractText(from: body, pattern: namePattern)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let contactEmail = extractText(from: body, pattern: emailPattern)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let description: String
        if let name = contactName {
            let direction = subject.lowercased().contains("sent") ? "to" : "from"
            let suffix    = contactEmail.map { " (\($0))" } ?? ""
            description   = "e-Transfer \(direction) \(name)\(suffix)"
        } else {
            description = subject
        }

        let date     = extractDate(from: body, fallbackDate: fallbackDate) ?? Date.now
        let currency = detectCurrency(from: body)
        // Default to "e-Transfer"; only override if detectCategory finds a stronger match.
        let detected = detectCategory(from: description, body: body)
        let category = detected == "Other" ? "e-Transfer" : detected

        return Transaction(
            date: date, amount: amount,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category, account: .chequing, currency: currency,
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

}
