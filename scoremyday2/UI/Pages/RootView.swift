import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    private let tabOrder: [RootTab] = [.deeds, .stats, .settings]

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
            .gesture(
                DragGesture()
                    .onEnded { value in
                        handleSwipe(value)
                    }
            )
        }
        .accentColor(accentColor)
        .preferredColorScheme(appEnvironment.settings.theme.preferredColorScheme)
    }

    private var accentColor: Color {
        if let hex = appEnvironment.settings.accentColorHex, !hex.isEmpty {
            return Color(hex: hex, fallback: .accentColor)
        } else {
            return .accentColor
        }
    }

    private func handleSwipe(_ value: DragGesture.Value) {
        let horizontalTranslation = value.translation.width
        let threshold: CGFloat = 50

        if horizontalTranslation < -threshold {
            moveToAdjacentTab(direction: 1)
        } else if horizontalTranslation > threshold {
            moveToAdjacentTab(direction: -1)
        }
    }

    private func moveToAdjacentTab(direction: Int) {
        guard let currentIndex = tabOrder.firstIndex(of: appEnvironment.selectedTab) else { return }

        let targetIndex = currentIndex + direction
        guard tabOrder.indices.contains(targetIndex) else { return }

        appEnvironment.selectedTab = tabOrder[targetIndex]
    }
}

#Preview {
    RootView()
        .environmentObject(AppEnvironment())
}
