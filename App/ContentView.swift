import Domain
import SwiftUI
import ViewModels

struct ContentView: View {
    let version: AppVersion
    let app: AppModel
    let sync: SyncModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                Text("Gym Companion")
                    .font(.largeTitle.bold())
                Text("Versión \(version.label)")
                    .foregroundStyle(.secondary)
                if let data = app.data {
                    Text("\(data.history.count) sesiones")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { SyncIndicator(sync: sync) }
            }
        }
        .syncPresentation(sync)
    }
}
