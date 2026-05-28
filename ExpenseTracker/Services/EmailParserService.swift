// EmailParserService.swift
// Responsibility: Orchestrates email parsing — decodes raw Gmail JSON, extracts the
//                 plain-text body, then dispatches to the appropriate parsing strategy
//                 based on the caller-supplied set of ParsingTemplates.
//                 Template implementations live in Services/ParsingTemplates/.
// Depends on: Foundation, Transaction model, ParsingTemplate
// Used by: SyncService
//
// ─────────────────────────────────────────────────────────────────────────────
// ⚠️  PATTERNS SECTION — update after Build Order Step 2.
//     Trigger a real transaction, open the alert email in Gmail → Show original,
//     and record the exact From address, Subject line, and body template for
//     both chequing and credit card. Then update the string constants below.
// ─────────────────────────────────────────────────────────────────────────────

import Foundation

class EmailParserService {

    // MARK: - Shared patterns (accessed by template extensions in ParsingTemplates/)

    let chequingKeywords   = ["chequing", "checking", "account alert", "bank account"]
    let creditCardKeywords = ["credit card", "visa", "mastercard", "card ending"]
    let eTransferKeywords  = ["interac", "e-transfer", "etransfer"]
    let refundKeywords     = ["refund", "return", "reversal", "chargeback"]
    let depositKeywords    = ["deposit", "received", "credited", "added"]
    let debitKeywords      = ["purchase", "payment", "withdrawal", "paid", "charged", "debit"]

    // UPDATE: if CIBC bodies use "CAD $X.XX" or "Amount: X.XX" without a "$", adjust.
    let amountPattern = #"\$([0-9,]+\.[0-9]{2})"#

    // UPDATE: replace with the exact field label CIBC uses ("Merchant:", "At:", "Store:").
    let merchantPatterns = [
        #"(?i)(?:Merchant|Store|Payee|At|Made at):\s*(.+)"#,
        #"(?i)purchase (?:at|from)\s+(.+)"#,
        #"(?i)transaction (?:at|with)\s+(.+)"#,
    ]

    // UPDATE: add or reorder formats to match whatever CIBC puts in the body.
    private let bodyDateFormats = [
        "MMMM d, yyyy", "MMM. d, yyyy", "MMM d, yyyy",
        "MMMM dd, yyyy", "d MMMM yyyy", "yyyy-MM-dd",
    ]
    let bodyDatePattern = #"(?i)(?:Date|Transaction Date|Posted):\s*([\w]+ [\d,]+\s+\d{4}|\d{4}-\d{2}-\d{2})"#

    // MARK: - Lazy formatters

    lazy var bodyDateFormatters: [DateFormatter] = bodyDateFormats.map { format in
        let f = DateFormatter()
        f.dateFormat = format
        f.locale = Locale(identifier: "en_US")
        return f
    }

    // Tried in order. Covers:
    //   "Sat, 24 May 2026 23:30:00 -0400"  — standard with weekday, 2-digit day
    //   "Sat, 4 May 2026 23:30:00 -0400"   — 1-digit day
    //   "24 May 2026 23:30:00 -0400"        — no weekday prefix
    //   "4 May 2026 23:30:00 -0400"         — no weekday, 1-digit
    lazy var rfc2822Formatters: [DateFormatter] = ["EEE, d MMM yyyy HH:mm:ss Z",
                                                    "d MMM yyyy HH:mm:ss Z"].map { fmt in
        let f = DateFormatter()
        f.dateFormat = fmt
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }

    // MARK: - Public API

    // More-specific templates are tried first so they get priority over the generic default.
    func parse(messageId: String, data: Data, templates: Set<ParsingTemplate>) -> Transaction? {
        guard let message = try? JSONDecoder().decode(GmailMessage.self, from: data) else {
            print("[Parser] ❌ JSON decode failed for message \(messageId)")
            return nil
        }

        let subject = message.payload.header(named: "Subject") ?? ""

        let subjectLower = subject.lowercased()
        if Constants.EmailFilters.ignoredSubjectKeywords.contains(where: { subjectLower.contains($0.lowercased()) }) {
            print("[Parser] ⏩ Skipped ignored subject in \(messageId) — subject: \(subject)")
            return nil
        }

        guard let body = extractBody(from: message.payload) else {
            print("[Parser] ❌ No text/plain or text/html body found in message \(messageId) — subject: \(subject)")
            return nil
        }

        // internalDate is milliseconds-since-epoch — no string parsing needed.
        // Fall back to the RFC 2822 Date header only when internalDate is absent.
        let fallbackDate: Date?
        if let ms = message.internalDate.flatMap({ Double($0) }) {
            fallbackDate = Date(timeIntervalSince1970: ms / 1000)
        } else {
            let raw = (message.payload.header(named: "Date") ?? "")
                .replacingOccurrences(of: #"\s*\([^)]+\)"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            fallbackDate = rfc2822Formatters.lazy.compactMap { $0.date(from: raw) }.first
            if fallbackDate == nil {
                print("[Parser] ⚠️  No valid date found for message \(messageId)")
            }
        }

        let tx: Transaction?
        if templates.contains(.creditCardPurchase),
           let t = parseCreditCardPurchase(body, subject: subject,
                                           messageId: messageId, fallbackDate: fallbackDate) {
            tx = t
        } else if templates.contains(.default) {
            tx = parseDefault(body, subject: subject, messageId: messageId, fallbackDate: fallbackDate)
        } else {
            print("[Parser] ⚠️  No enabled template matched message \(messageId) — subject: \(subject)")
            return nil
        }

        guard let tx else { return nil }

        guard tx.date >= Constants.Sync.earliestDate else {
            print("[Parser] ⏩ Skipped pre-cutoff transaction in \(messageId) — date: \(tx.date)")
            return nil
        }

        return tx
    }

    // MARK: - Shared extraction helpers (internal so template extensions can call them)

    // (category name, keywords) pairs checked in priority order — first match wins.
    // Ordering matters: more specific entries come before broader ones so e.g.
    // "amazon prime" matches Subscriptions before "amazon" matches Shopping.
    private let categoryKeywords: [(String, [String])] = [
        ("Groceries",     ["loblaws", "sobeys", "no frills", "freshco", "food basics",
                            "superstore", "safeway", "iga", "provigo", "farm boy", "longos",
                            "whole foods", "t&t", "maxi", "super c", "walmart", "grocery"]),
        ("Food & Dining", ["tim horton", "mcdonald", "burger king", "wendy", "subway",
                            "pizza", "kfc", "starbucks", "restaurant", "cafe", "sushi",
                            "a&w", "dairy queen", "popeyes", "swiss chalet", "harvey's",
                            "second cup", "pita pit", "uber eats", "skip the dishes",
                            "doordash", "instacart", "bistro", "eatery"]),
        ("Transport",     ["uber", "lyft", "taxi", "ttc", "oc transpo", "presto",
                            "petro-canada", "shell", "esso", "sunoco",
                            "go transit", "via rail", "air canada", "westjet", "parking"]),
        ("Subscriptions", ["netflix", "spotify", "amazon prime", "disney", "youtube premium",
                            "adobe", "microsoft", "dropbox", "icloud", "apple.com",
                            "google one", "crave", "dazn", "paramount",
                            "openai", "chatgpt", "anthropic", "claude"]),
        ("Health",        ["shoppers drug mart", "rexall", "pharmasave", "pharmacy",
                            "drug mart", "dental", "clinic", "hospital",
                            "physiotherapy", "massage therapy", "optometrist"]),
        ("Shopping",      ["amazon", "ebay", "h&m", "zara", "gap", "old navy", "winners",
                            "homesense", "ikea", "the bay", "nordstrom", "sephora",
                            "indigo", "dollarama", "best buy", "staples",
                            "canadian tire", "sport chek", "muji", "miniso"]),
        ("Entertainment", ["cineplex", "ticketmaster", "steam", "playstation", "xbox",
                            "nintendo", "airbnb", "expedia", "hotels.com"]),
    ]

    // Checks description then body against the keyword table.
    // Returns the first matching category name, or "Other" if nothing matches.
    func detectCategory(from description: String, body: String) -> String {
        let target = (description + " " + body).lowercased()
        for (category, keywords) in categoryKeywords {
            if keywords.contains(where: { target.contains($0) }) { return category }
        }
        return "Other"
    }

    func detectCurrency(from body: String) -> Currency {
        let lower = body.lowercased()
        if lower.contains("usd") || lower.contains("u.s. dollar") || lower.contains("us dollar") {
            return .usd
        }
        if lower.contains("cny") || lower.contains("rmb") || lower.contains("chinese yuan")
            || lower.contains("人民币") || lower.contains("¥") {
            return .cny
        }
        return .cad
    }

    func extractAmount(from body: String) -> Double? {
        guard let raw = extractText(from: body, pattern: amountPattern) else { return nil }
        let stripped = raw.replacingOccurrences(of: ",", with: "")
        guard let value = Double(stripped), value > 0 else { return nil }
        return value
    }

    func extractDate(from body: String, fallbackDate: Date?) -> Date? {
        if let dateStr = extractText(from: body, pattern: bodyDatePattern),
           let date = parseBodyDate(dateStr.trimmingCharacters(in: .whitespaces)) {
            return date
        }
        return fallbackDate
    }

    func extractText(from text: String, pattern: String, group: Int = 1) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > group,
              let captureRange = Range(match.range(at: group), in: text)
        else { return nil }
        return String(text[captureRange])
    }

    func decodeBase64URL(_ encoded: String) -> String? {
        var base64 = encoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 { base64 += String(repeating: "=", count: 4 - remainder) }
        guard let data = Data(base64Encoded: base64) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func parseBodyDate(_ string: String) -> Date? {
        for formatter in bodyDateFormatters {
            if let date = formatter.date(from: string) { return date }
        }
        print("[Parser] ⚠️  Could not parse date string: \"\(string)\"")
        return nil
    }

    // MARK: - Body extraction from Gmail message payload

    // Tries text/plain first (cleanest for regex). Falls back to HTML with tags stripped
    // because many transactional emails (including CIBC) are multipart with no plain part.
    private func extractBody(from payload: GmailMessage.Payload) -> String? {
        if let plain = firstPart(mimePrefix: "text/plain", in: payload) { return plain }
        if let html  = firstPart(mimePrefix: "text/html",  in: payload) { return stripHtml(html) }
        return nil
    }

    private func firstPart(mimePrefix: String, in payload: GmailMessage.Payload) -> String? {
        if payload.mimeType?.hasPrefix(mimePrefix) == true,
           let data = payload.body?.data {
            return decodeBase64URL(data)
        }
        if let parts = payload.parts {
            return firstPart(mimePrefix: mimePrefix, in: parts)
        }
        return nil
    }

    private func firstPart(mimePrefix: String, in parts: [GmailMessage.Part]) -> String? {
        for part in parts {
            if part.mimeType?.hasPrefix(mimePrefix) == true,
               let data = part.body?.data,
               let decoded = decodeBase64URL(data) {
                return decoded
            }
            if let subParts = part.parts,
               let result = firstPart(mimePrefix: mimePrefix, in: subParts) {
                return result
            }
        }
        return nil
    }

    private func stripHtml(_ html: String) -> String {
        var s = html
        s = s.replacingOccurrences(of: "&nbsp;",  with: " ")
        s = s.replacingOccurrences(of: "&amp;",   with: "&")
        s = s.replacingOccurrences(of: "&lt;",    with: "<")
        s = s.replacingOccurrences(of: "&gt;",    with: ">")
        s = s.replacingOccurrences(of: "&quot;",  with: "\"")
        s = s.replacingOccurrences(of: "&#39;",   with: "'")
        s = s.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        return s.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
    }
}

// MARK: - Gmail message JSON model (private — only used in parse())

private struct GmailMessage: Decodable {
    let id: String
    // Unix milliseconds since epoch — always present for format=full requests.
    // More reliable than the RFC 2822 Date header, which requires fragile string parsing.
    let internalDate: String?
    let payload: Payload

    struct Payload: Decodable {
        let mimeType: String?
        let headers:  [Header]?
        let body:     Body?
        let parts:    [Part]?

        func header(named name: String) -> String? {
            headers?.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
        }
    }

    struct Header: Decodable { let name: String; let value: String }

    struct Body: Decodable {
        let data: String?  // base64url encoded; absent when size == 0 (multipart container)
        let size: Int?
    }

    struct Part: Decodable {
        let mimeType: String?
        let body:     Body?
        let parts:    [Part]?
    }
}
