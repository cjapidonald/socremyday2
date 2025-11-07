import SwiftUI

struct SparklineView: View {
    var values: [Double]
    var lineColor: Color = Color.themeMotionGreen
    var fillColor: Color = Color.themeMotionGreen.opacity(0.22)
    var gridColor: Color = Color.primary.opacity(0.08)
    var horizontalGridLines: Int = 3
    var verticalGridLines: Int = 5

    private var normalized: [Double] {
        guard !values.isEmpty else { return [] }
        guard let max = values.max(), let min = values.min() else { return [] }

        if max == min {
            let fallbackCount = Swift.max(values.count, 2)
            if max == 0 {
                return Array(repeating: 0, count: fallbackCount)
            } else {
                return Array(repeating: 0.5, count: fallbackCount)
            }
        }

        let delta = max - min
        return values.map { ($0 - min) / delta }
    }

    var body: some View {
        GeometryReader { proxy in
            let values = normalized
            let height = max(proxy.size.height, 1)
            let width = max(proxy.size.width, 1)
            let count = values.count
            let step = count > 1 ? width / CGFloat(count - 1) : 0

            let points: [CGPoint] = values.enumerated().map { index, value in
                let x = CGFloat(index) * step
                let y = height - CGFloat(value) * height
                return CGPoint(x: x, y: y)
            }

            ZStack {
                GridPatternBackground(
                    horizontalDivisions: horizontalGridLines,
                    verticalDivisions: max(0, min(verticalGridLines, max(count - 1, 0))),
                    lineWidth: 0.6,
                    color: gridColor
                )

                if count >= 2 {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: height))
                        for point in points {
                            path.addLine(to: point)
                        }
                        path.addLine(to: CGPoint(x: width, y: height))
                        path.closeSubpath()
                    }
                    .fill(fillColor)

                    Path { path in
                        if let first = points.first {
                            path.move(to: first)
                            for point in points.dropFirst() {
                                path.addLine(to: point)
                            }
                        }
                    }
                    .stroke(lineColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                } else if let only = points.first {
                    Circle()
                        .fill(lineColor)
                        .frame(width: 4, height: 4)
                        .position(only)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
