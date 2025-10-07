import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment

    var body: some View {
        ZStack {
            LiquidBackgroundView()
                .ignoresSafeArea()

            TabView {
                DeedsPage()
                    .tabItem {
                        Label("Deeds", systemImage: "square.grid.3x3")
                    }

                StatsPage()
                    .tabItem {
                        Label("Stats", systemImage: "chart.xyaxis.line")
                    }

                SettingsPage()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
            }
        }
        .glassBackground(
            cornerRadius: 0,
            tint: Color(appEnvironment.settings.accentColorIdentifier),
            warpStrength: 2
        )
        .accentColor(Color(appEnvironment.settings.accentColorIdentifier))
    }
}

#Preview {
    RootView()
        .environmentObject(AppEnvironment())
}
