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
            tint: accentColor,
            warpStrength: 2
        )
        .accentColor(accentColor)
    }

    private var accentColor: Color {
        if let hex = appEnvironment.settings.accentColorHex, !hex.isEmpty {
            return Color(hex: hex, fallback: .accentColor)
        } else {
            return .accentColor
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppEnvironment())
}
