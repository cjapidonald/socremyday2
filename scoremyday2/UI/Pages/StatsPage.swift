import SwiftUI

struct StatsPage: View {
    var body: some View {
        ZStack {
            LiquidBackgroundView()
            Text("Stats")
                .font(.largeTitle)
                .padding()
        }
    }
}

#Preview {
    StatsPage()
}
