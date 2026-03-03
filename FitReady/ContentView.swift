import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            MainReadinessView()
                .tabItem { Label("Today",    systemImage: "house.fill") }

            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.bar.fill") }

            ProfileView()
                .tabItem { Label("Profile",  systemImage: "person.fill") }

            FoodView()
                .tabItem { Label("Food",     systemImage: "fork.knife") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(.purple)
    }
}
