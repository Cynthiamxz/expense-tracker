// DonutChartView.swift
// Responsibility: Renders the category spending donut chart. Each segment is a
//                 Circle().trim() arc coloured by the category's hex colour.
//                 The centre shows the total spending amount in a serif font.
// Depends on: SwiftUI, Constants (design tokens)
// Used by: SummaryView (inside the chart surface card)

import SwiftUI

struct DonutChartView: View {
    let breakdown: [(name: String, amount: Double, colorHex: String)]

    private let lineWidth: CGFloat = 30

    var total: Double {
        breakdown.reduce(0) { $0 + $1.amount }
    }

    private var segments: [(start: CGFloat, end: CGFloat, colorHex: String)] {
        guard total > 0 else { return [] }
        var result: [(start: CGFloat, end: CGFloat, colorHex: String)] = []
        var cumulative: CGFloat = 0
        for entry in breakdown {
            let fraction = CGFloat(entry.amount / total)
            result.append((start: cumulative, end: cumulative + fraction, colorHex: entry.colorHex))
            cumulative += fraction
        }
        return result
    }

    var body: some View {
        ZStack {
            if breakdown.isEmpty {
                Circle()
                    .stroke(Color(hex: Constants.Design.mutedText).opacity(0.25), lineWidth: lineWidth)
            } else {
                ForEach(segments.indices, id: \.self) { i in
                    let seg = segments[i]
                    Circle()
                        .trim(from: seg.start, to: seg.end)
                        .stroke(
                            Color(hex: seg.colorHex),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                        )
                        .rotationEffect(.degrees(-90))
                }
            }

            VStack(spacing: 2) {
                Text(total, format: .currency(code: "CAD").presentation(.narrow))
                    .font(.system(.callout, design: .serif).bold())
                    .foregroundStyle(Color(hex: Constants.Design.primaryText))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                Text("SPENT")
                    .font(.system(size: 9).monospaced())
                    .foregroundStyle(Color(hex: Constants.Design.secondaryText))
            }
            .padding(lineWidth + 4)
        }
        .padding(lineWidth / 2)
    }
}

#Preview {
    DonutChartView(breakdown: [
        ("Food & Dining", 450.0, "#C4A882"),
        ("Transport",     120.0, "#7B9EC4"),
        ("Other",          80.0, "#C0BAB4"),
    ])
    .frame(width: 200, height: 200)
}
