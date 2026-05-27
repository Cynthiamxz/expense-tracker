// CategoryLegendView.swift
// Responsibility: Renders the ordered legend rows that appear below the donut chart —
//                 one row per category showing: colour dot, name, amount.
// Depends on: SwiftUI, Constants (design tokens)
// Used by: SummaryView (inside the chart surface card, below DonutChartView)

import SwiftUI

struct CategoryLegendView: View {
    let breakdown: [(name: String, amount: Double, colorHex: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if breakdown.isEmpty {
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(Color(hex: Constants.Design.mutedText))
            } else {
                ForEach(breakdown, id: \.name) { entry in
                    LegendRowView(name: entry.name, amount: entry.amount, colorHex: entry.colorHex)
                }
            }
        }
    }
}

private struct LegendRowView: View {
    let name: String
    let amount: Double
    let colorHex: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: 8, height: 8)
            Text(name)
                .font(.caption)
                .foregroundStyle(Color(hex: Constants.Design.secondaryText))
                .lineLimit(1)
            Spacer()
            Text(amount, format: .currency(code: "CAD").presentation(.narrow))
                .font(.caption.monospaced())
                .foregroundStyle(Color(hex: Constants.Design.primaryText))
        }
    }
}

#Preview {
    CategoryLegendView(breakdown: [
        ("Food & Dining", 450.0, "#C4A882"),
        ("Transport",     120.0, "#7B9EC4"),
        ("Other",          80.0, "#C0BAB4"),
    ])
    .padding()
}
