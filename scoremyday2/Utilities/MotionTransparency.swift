import SwiftUI

struct MotionTransparencyEnv: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let disableParticles: (Bool) -> Void
    let setOpaqueBackgrounds: (Bool) -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: reduceMotion, perform: disableParticles)
            .onChange(of: reduceTransparency, perform: setOpaqueBackgrounds)
            .onAppear {
                disableParticles(reduceMotion)
                setOpaqueBackgrounds(reduceTransparency)
            }
    }
}
