import SwiftUI

struct ContentView: View {
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    private let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Gym Companion")
                .font(.largeTitle.bold())
            Text("Versión \(version) (\(build))")
                .foregroundStyle(.secondary)
            Text("Instalada desde el NAS por WiFi")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
