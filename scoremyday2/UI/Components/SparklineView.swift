import SwiftUI

struct SparklineView: View {
    var values: [Double]
    var lineColor: Color = Color.white.opacity(0.9)
    var fillColor: Color = Color.white.opacity(0.2)

    private var normalized: [Double] {
        guard let max = values.max(), let min = values.min(), max != min else {
            return Array(repeating: 0.5, count: Swift.max(values.count, 2))
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
