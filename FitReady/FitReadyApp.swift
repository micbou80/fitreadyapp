import SwiftUI

@main
struct FitReadyApp: App {

    @StateObject private var healthKit = HealthKitManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthKit)
                .task {
                    await healthKit.requestAuthorization()
                }
        }
    }
}
