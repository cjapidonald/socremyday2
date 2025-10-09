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
                .background(
                    MatrixRainBackground()
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .accessibilityHidden(true)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.green.opacity(0.35), lineWidth: 1)
                )
                .accessibilityHidden(true)
        }
    }
}

private struct MatrixRainBackground: View {
    private let digits = Array("0123456789")

    var body: some View {
        GeometryReader { geometry in
            let columnCount = max(8, Int(geometry.size.width / 28))
            let rowCount = max(12, Int(geometry.size.height / 18))
            let columnWidth = geometry.size.width / CGFloat(columnCount)
            let rowHeight = geometry.size.height / CGFloat(rowCount)
            let fontSize = max(10, min(columnWidth, rowHeight) * 0.7)

            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.92),
                        Color(red: 0.0, green: 0.25, blue: 0.0).opacity(0.96)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<rowCount, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<columnCount, id: \.self) { column in
                                let digitIndex = (row * 73 + column * 97) % digits.count
                                let brightnessSeed = Double((row * 19 + column * 11) % 60)
                                Text(String(digits[digitIndex]))
                                    .font(.system(size: fontSize, weight: .heavy, design: .monospaced))
                                    .foregroundColor(
                                        Color(
                                            hue: 120.0 / 360.0,
                                            saturation: 0.85,
                                            brightness: 0.35 + brightnessSeed / 100.0
                                        )
                                    )
                                    .frame(width: columnWidth, height: rowHeight, alignment: .center)
                            }
                        }
                    }
                }
                .padding(.horizontal, columnWidth * 0.25)
                .padding(.vertical, rowHeight * 0.25)
                .blendMode(.plusLighter)
                .opacity(0.85)
            }
        }
    }
}
