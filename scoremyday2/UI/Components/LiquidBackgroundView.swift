import SwiftUI

struct LiquidBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let base = colorScheme == .dark ? Color.black : Color.white
        base
            .ignoresSafeArea()
    }
}

#Preview {
    LiquidBackgroundView()
}
