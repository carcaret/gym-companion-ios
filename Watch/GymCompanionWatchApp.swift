import SwiftUI

@main
struct GymCompanionWatchApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 8) {
                Image(systemName: "dumbbell.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                Text("Gym")
                    .font(.headline)
                Text("Prueba del reloj")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
