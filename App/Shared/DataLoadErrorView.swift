import Presentation
import SwiftUI
import ViewModels

/// Los datos del iPhone no se pueden leer: lo dice y ofrece reintentar y, con GitHub configurado,
/// descargarlos de allí (que los guarda encima).
struct DataLoadErrorView: View {
    let model: AppModel
    let sync: SyncModel
    @State private var isWorking = false

    var body: some View {
        ContentUnavailableView {
            Label(DataErrorText.loadTitle, systemImage: "exclamationmark.triangle")
        } description: {
            Text(DataErrorText.loadMessage)
        } actions: {
            Button(DataErrorText.retry) { run { await model.start() } }
                .accessibilityIdentifier("data-retry")
            if sync.status.state != .disabled {
                Button(DataErrorText.download) { run { await sync.download() } }
                    .accessibilityIdentifier("data-download")
            }
            if isWorking { ProgressView() }
        }
        .disabled(isWorking)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .accessibilityIdentifier("data-load-error")
    }

    private func run(_ work: @escaping () async -> Void) {
        isWorking = true
        Task {
            await work()
            isWorking = false
        }
    }
}
