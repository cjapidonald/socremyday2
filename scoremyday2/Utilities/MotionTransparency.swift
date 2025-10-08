import SwiftUI

struct MotionTransparencyEnv: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let disableParticles: (Bool) -> Void
    let setOpaqueBackgrounds: (Bool) -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: reduceMotion) { _, value in disableParticles(value) }
            .onChange(of: reduceTransparency) { _, value in setOpaqueBackgrounds(value) }
            .onAppear {
                disableParticles(reduceMotion)
                setOpaqueBackgrounds(reduceTransparency)
            }
    }
}
