import SwiftUI

extension Notification.Name {
    static let switchToTodayTab = Notification.Name("switchToTodayTab")
}

struct ContentView: View {

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // V2 Today screen — decision-first, low-friction
            TodayView()
                .tabItem { Label("Today",    systemImage: "house.fill") }
                .tag(0)

            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.bar.fill") }
                .tag(1)

            NavigationStack { ProfileView() }
                .tabItem { Label("Profile",  systemImage: "person.fill") }
                .tag(2)

            FoodView()
                .tabItem { Label("Food",     systemImage: "fork.knife") }
                .tag(3)
        }
        .tint(AppColors.accent)
        .onReceive(NotificationCenter.default.publisher(for: .switchToTodayTab)) { _ in
            selectedTab = 0
        }
    }
}

// NOTE: MainReadinessView (V1) is preserved in MainReadinessView.swift.
// Swap it back into the Today tab above to compare the two designs.
