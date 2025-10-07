import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment

    var body: some View {
        ZStack {
            LiquidBackgroundView()
                .ignoresSafeArea()

            TabView(selection: Binding(
                get: { appEnvironment.selectedTab },
                set: { appEnvironment.selectedTab = $0 }
            )) {
                DeedsPage()
                    .tabItem {
                        Label("Deeds", systemImage: "square.grid.3x3")
                    }
                    .tag(RootTab.deeds)

                StatsPage()
                    .tabItem {
                        Label("Stats", systemImage: "chart.xyaxis.line")
                    }
                    .tag(RootTab.stats)

                SettingsPage()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(RootTab.settings)
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
