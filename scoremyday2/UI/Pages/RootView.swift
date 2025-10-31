import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    private let tabOrder: [RootTab] = [.deeds, .stats, .settings]
    @State private var showContent = false

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
            .opacity(showContent ? 1 : 0)
            .gesture(
                DragGesture()
                    .onEnded { value in
                        handleSwipe(value)
                    }
            )
        }
        .accentColor(accentColor)
        .preferredColorScheme(appEnvironment.settings.theme.preferredColorScheme)
        .onAppear {
            // Trick to trigger data load: Start on stats, then auto-switch to deeds
            // This ensures Core Data is fully initialized before showing deeds
            if !appEnvironment.hasPerformedInitialLoad {
                appEnvironment.hasPerformedInitialLoad = true

                // Show content with fade-in
                withAnimation(.easeIn(duration: 0.2)) {
                    showContent = true
                }

                // Switch to deeds after stats loads data
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        appEnvironment.selectedTab = .deeds
                    }
                }
            } else {
                // If already loaded, show immediately
                showContent = true
            }
        }
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
