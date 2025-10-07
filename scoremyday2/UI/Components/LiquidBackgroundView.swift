import SwiftUI

struct LiquidBackgroundView: View {
    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .ignoresSafeArea()
    }
}

#Preview {
    LiquidBackgroundView()
}
