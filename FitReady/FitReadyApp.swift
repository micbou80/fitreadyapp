import SwiftUI

@main
struct FitReadyApp: App {

    @StateObject private var healthKit = HealthKitManager()
    @AppStorage("notificationLevel") private var notificationLevel: String = "moderate"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthKit)
                .preferredColorScheme(.dark)
                .task {
                    await healthKit.requestAuthorization()
                    NotificationManager.shared.requestPermission()
                    NotificationManager.shared.reschedule(level: notificationLevel)
                }
        }
    }
}
