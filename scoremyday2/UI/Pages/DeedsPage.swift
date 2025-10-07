import SwiftUI

struct DeedsPage: View {
    var body: some View {
        ZStack {
            LiquidBackgroundView()
            Text("Deeds")
                .font(.largeTitle)
                .padding()
        }
    }
}

#Preview {
    DeedsPage()
}
