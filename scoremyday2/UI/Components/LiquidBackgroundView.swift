import SwiftUI

struct LiquidBackgroundView: View {
    var body: some View {
        Color(hex: "#001F3F", fallback: .blue)
            .ignoresSafeArea()
    }
}

#Preview {
    LiquidBackgroundView()
}
