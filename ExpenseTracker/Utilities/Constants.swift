// Constants.swift
// Responsibility: Single source of truth for app-wide literals — Gmail API endpoints,
//                 OAuth configuration, Keychain key strings, and the default category
//                 seed data. Nothing here contains business logic.
// Depends on: Foundation (nothing else)
// Used by: GmailAuthService (OAuth URLs), GmailFetchService (base URL),
//          KeychainHelper callers (key constants), Category.seedDefaults (seed data)

import Foundation

enum Constants {
    enum Gmail {
        static let baseURL        = "https://gmail.googleapis.com/gmail/v1"
        static let authEndpoint   = "https://accounts.google.com/o/oauth2/v2/auth"
        static let tokenEndpoint  = "https://oauth2.googleapis.com/token"
        // Read-only Gmail scope — the app never sends or modifies email.
        static let scope          = "https://www.googleapis.com/auth/gmail.readonly"
        // Must match the URL scheme registered in Info.plist under CFBundleURLSchemes.

        static let clientID       = "677584193102-gbm5kcbh4to4f8jg79u3ab4h912417ou.apps.googleusercontent.com"
        // Must be the reversed client ID — matches CFBundleURLSchemes in Info.plist and
        // the redirect URI Google Cloud Console auto-registers for iOS app type clients.
        static let redirectScheme = "com.googleusercontent.apps.677584193102-gbm5kcbh4to4f8jg79u3ab4h912417ou"
        static let redirectURI    = "\(redirectScheme):/oauth2callback"
    }

    enum Labels {
        // The Gmail label the app watches. Users can add more in Settings → Label Rules.
        static let defaultLabel = "cibc-transactions"
    }

    enum Sync {
        // Transactions dated before this day are ignored during parsing and never stored.
        static let earliestDate: Date = {
            var c = DateComponents()
            c.year = 2026; c.month = 5; c.day = 1
            return Calendar(identifier: .gregorian).date(from: c)!
        }()
    }

    enum EmailFilters {
        // Emails whose subject contains any of these strings (case-insensitive) are
        // skipped entirely before any parsing attempt. Add new entries as needed.
        static let ignoredSubjectKeywords: [String] = [
            "eStatement Alert",
            "Important document available",
            "account offer",
        ]
    }

    enum Keychain {
        // Keys used by KeychainHelper — keep centralised so callers never hard-code strings.
        static let accessTokenKey  = "gmail_access_token"
        static let refreshTokenKey = "gmail_refresh_token"
        static let tokenExpiryKey  = "gmail_token_expiry"
        static let emailKey        = "gmail_connected_email"
    }

    enum Categories {
        // Category names treated as income (green, excluded from spending totals).
        // Add sub-category names here as the income taxonomy grows —
        // e.g. "Income - Salary", "Income - Freelance".
        static let incomeNames: Set<String> = ["Income"]
    }

    enum DefaultCategories {
        // (name, colorHex) pairs — consumed by Category.seedDefaults(into:) on first launch.
        static let all: [(name: String, colorHex: String)] = [
            ("Food & Dining", "#C4A882"),
            ("Groceries",     "#8BAF8B"),
            ("Transport",     "#7B9EC4"),
            ("Subscriptions", "#A891C4"),
            ("Health",        "#C4A8A8"),
            ("Shopping",      "#B8C4A8"),
            ("Entertainment", "#C4BAA8"),
            ("Income",        "#8BAF8B"),
            ("e-Transfer",    "#A8B8C4"),
            ("Other",         "#C0BAB4"),
        ]
    }

    enum Design {
        // Hex strings matching the design token table in the spec (Section 5.1).
        static let background      = "#FFFFFF"
        static let surface         = "#F8F8F8"
        static let dateBand        = "#F0EBE3"
        static let dateBandBorder  = "#E8E0D8"
        static let primaryText     = "#1A1A1A"
        static let secondaryText   = "#999999"
        static let mutedText       = "#BBBBBB"
        static let incomeGreenBg   = "#EDF5EC"
        static let incomeGreenText = "#2A5228"
        static let spentRedBg      = "#FEF2F2"
        static let spentRedText    = "#7F1D1D"
        static let deleteRedText   = "#991B1B"
        static let fab             = "#2563EB"
    }
}
