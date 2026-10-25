import Domain
import SwiftUI

struct ContentView: View {
    let version: AppVersion

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Gym Companion")
                .font(.largeTitle.bold())
            Text("Versión \(version.label)")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView(version: AppVersion(marketing: "0.1", build: "1"))
}
