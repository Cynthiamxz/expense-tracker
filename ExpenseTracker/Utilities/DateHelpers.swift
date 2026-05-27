// DateHelpers.swift
// Responsibility: Centralised date formatting and calendar arithmetic used
//                 throughout the UI. Keeping formatting here ensures consistent
//                 output whenever the same date appears in different views.
// Depends on: Foundation
// Used by: TransactionsViewModel (grouping key), DateGroupView (section header),
//          SyncService / TransactionsViewModel (sync-ago string),
//          SummaryViewModel (month range filtering, month label)

import Foundation

struct DateHelpers {
    // MARK: - Private formatters
    // DateFormatter creation is expensive — keep one instance per format.

    private static let groupKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        return f
    }()

    private static let sectionHeaderFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"   // e.g. "May 24, 2026"
        f.locale = Locale.current
        return f
    }()

    private static let monthLabelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"     // e.g. "May 2026"
        f.locale = Locale.current
        return f
    }()

    // MARK: - Public API

    // Returns "yyyy-MM-dd" — used as the dictionary key when grouping transactions
    // by calendar day in TransactionsViewModel.
    static func groupKey(for date: Date) -> String {
        groupKeyFormatter.string(from: date)
    }

    // Returns an uppercased short date like "MAY 24" for the date band header.
    static func sectionHeader(for date: Date) -> String {
        sectionHeaderFormatter.string(from: date).uppercased()
    }

    // Returns a human-readable relative string for the sync bar:
    // "just now" · "X min ago" · "Xh ago"
    static func syncAgoString(from date: Date) -> String {
        let interval = Date.now.timeIntervalSince(date)
        switch interval {
        case ..<60:
            return "just now"
        case 60..<3600:
            let minutes = Int(interval / 60)
            return "\(minutes) min ago"
        default:
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        }
    }

    // Returns "May 2026" — the centred label between the month-nav chevrons.
    static func monthLabel(for date: Date) -> String {
        monthLabelFormatter.string(from: date)
    }

    // Returns the half-open interval [firstInstantOfMonth, firstInstantOfNextMonth).
    // Callers that need an inclusive end can subtract 1 second from `end`.
    // SummaryViewModel uses `date >= start && date < end` with the half-open form.
    static func monthRange(for date: Date) -> (start: Date, end: Date) {
        guard let interval = Calendar.current.dateInterval(of: .month, for: date) else {
            // Fallback: return the same instant for both bounds (empty range).
            return (start: date, end: date)
        }
        return (start: interval.start, end: interval.end)
    }

    // Returns the first instant of the month preceding `date`.
    static func previousMonth(from date: Date) -> Date {
        Calendar.current.date(byAdding: .month, value: -1, to: date) ?? date
    }

    // Returns the first instant of the month following `date`.
    static func nextMonth(from date: Date) -> Date {
        Calendar.current.date(byAdding: .month, value: 1, to: date) ?? date
    }
}
