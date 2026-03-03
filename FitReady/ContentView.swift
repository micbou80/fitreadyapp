import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            // V2 Today screen — decision-first, low-friction
            TodayView()
                .tabItem { Label("Today",    systemImage: "house.fill") }

            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.bar.fill") }

            NavigationStack { ProfileView() }
                .tabItem { Label("Profile",  systemImage: "person.fill") }

            FoodView()
                .tabItem { Label("Food",     systemImage: "fork.knife") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(AppColors.accent)
    }
}

// NOTE: MainReadinessView (V1) is preserved in MainReadinessView.swift.
// Swap it back into the Today tab above to compare the two designs.
