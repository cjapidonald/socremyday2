import SwiftUI

struct LiquidBackgroundView: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                Color.themeBackground

                AngularGradient(
                    colors: [
                        .themeMotionGreen.opacity(0.8),
                        .themePulsePurple.opacity(0.75),
                        .themeChargeBlue.opacity(0.75),
                        .themeMotionGreen.opacity(0.8)
                    ],
                    center: .center
                )
                .frame(width: size.width * 1.6, height: size.width * 1.6)
                .offset(x: size.width * 0.12, y: -size.height * 0.3)
                .blur(radius: 180)
                .blendMode(.screen)

                RadialGradient(
                    colors: [Color.themePulsePurple.opacity(0.55), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 0.95
                )
                .offset(x: -size.width * 0.2, y: -size.height * 0.25)
                .blur(radius: 120)
                .blendMode(.screen)

                RadialGradient(
                    colors: [Color.themeChargeBlue.opacity(0.5), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: max(size.width, size.height)
                )
                .offset(x: size.width * 0.25, y: size.height * 0.2)
                .blur(radius: 140)
                .blendMode(.screen)

                LinearGradient(
                    colors: [
                        Color.themeMotionGreen.opacity(0.35),
                        Color.clear,
                        Color.themePulsePurple.opacity(0.25)
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
                .blendMode(.screen)
                .opacity(0.9)
            }
            .compositingGroup()
            .ignoresSafeArea()
        }
    }
}

#Preview {
    LiquidBackgroundView()
}
