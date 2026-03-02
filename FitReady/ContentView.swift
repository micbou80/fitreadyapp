import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            MainReadinessView()
                .tabItem { Label("Today",    systemImage: "house.fill") }

            HistoryView()
                .tabItem { Label("Trends",   systemImage: "chart.line.uptrend.xyaxis") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(.purple)
    }
}
