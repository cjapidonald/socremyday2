import Foundation
import SwiftUI

struct StatsChartContainer<ChartContent: View>: View {
    @Environment(\.sizeCategory) private var sizeCategory

    let points: [DailyStatPoint]
    let chart: () -> ChartContent

    private var fallbackPoints: [DailyStatPoint] {
        Array(points.suffix(14).reversed())
    }

    var body: some View {
        if sizeCategory.isAccessibilityCategory {
            List(fallbackPoints) { point in
                HStack {
                    Text(point.date, style: .date)
                    Spacer()
                    Text("\(Int(point.value.rounded()))")
                        .monospacedDigit()
                        .bold()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "\(point.date.formatted(date: .abbreviated, time: .omitted)), value \(Int(point.value.rounded()))"
                )
            }
            .listStyle(.plain)
            .scrollDisabled(true)
            .frame(maxHeight: CGFloat(max(fallbackPoints.count, 1)) * 44)
        } else {
            chart()
                .accessibilityHidden(true)
        }
    }
}
