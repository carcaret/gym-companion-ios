import Presentation
import SwiftUI
import ViewModels

/// Los datos del iPhone no se pueden leer: en lugar de las pestañas, lo dice y ofrece reintentar y,
/// con GitHub configurado, sustituirlos por los de GitHub, que se confirma antes (el fichero
/// estropeado se pierde).
struct DataLoadErrorView: View {
    let model: AppModel
    let sync: SyncModel
    @State private var isWorking = false
    @State private var isDownloadConfirmationPresented = false

    var body: some View {
        ContentUnavailableView {
            Label(DataErrorText.loadTitle, systemImage: "exclamationmark.triangle")
        } description: {
            Text(DataErrorText.loadMessage)
        } actions: {
            // Lo más probable es reintentar: destacado, como la acción principal de las píldoras.
            Button(DataErrorText.retry) { run { await model.start() } }
                .buttonStyle(.pill)
                .accessibilityIdentifier("data-retry")
            if sync.offersDownload {
                Button(SettingsText.download, role: .destructive) { isDownloadConfirmationPresented = true }
                    .accessibilityIdentifier("data-download")
                    // Colgado del botón: en iOS 26 el diálogo sale como globo que apunta a su vista.
                    .confirmationDialog(SyncText.downloadTitle, isPresented: $isDownloadConfirmationPresented,
                                        titleVisibility: .visible) {
                        Button(SyncText.downloadConfirm, role: .destructive) { run { await sync.download() } }
                        Button(FormText.cancel, role: .cancel) {}
                    } message: {
                        Text(SyncText.downloadWarning)
                    }
            }
            if isWorking { ProgressView() }
        }
        .disabled(isWorking)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    private func run(_ work: @escaping () async -> Void) {
        isWorking = true
        Task {
            await work()
            isWorking = false
        }
    }
}
