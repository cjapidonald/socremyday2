import SwiftUI

struct GridPatternBackground: View {
    var horizontalDivisions: Int
    var verticalDivisions: Int
    var lineWidth: CGFloat = 0.6
    var color: Color = Color.white.opacity(0.12)

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            Path { path in
                if horizontalDivisions > 0 {
                    let step = height / CGFloat(horizontalDivisions + 1)
                    for index in 1...horizontalDivisions {
                        let y = CGFloat(index) * step
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                }

                if verticalDivisions > 0 {
                    let step = width / CGFloat(verticalDivisions + 1)
                    for index in 1...verticalDivisions {
                        let x = CGFloat(index) * step
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                    }
                }
            }
            .stroke(color, lineWidth: lineWidth)
        }
        .allowsHitTesting(false)
    }
}
