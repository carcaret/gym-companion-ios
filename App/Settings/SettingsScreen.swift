import Application
import Domain
import Presentation
import SwiftUI
import ViewModels

/// La pestaña Ajustes: sincronización con GitHub y versión de la app. Solo pinta `SettingsModel`.
struct SettingsScreen: View {
    @Bindable var model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(SettingsText.githubSection).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.text)
                    HStack {
                        Text(SettingsText.status).foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text(statusText).foregroundStyle(Theme.text)
                    }
                    .font(.system(size: 14))
                    field(SettingsText.repository) {
                        TextField(SettingsText.repository, text: $model.repository, prompt: Text(SettingsText.repositoryPlaceholder))
                            .accessibilityIdentifier("settings-repository")
                    }
                    field(SettingsText.branch) {
                        TextField(SettingsText.branch, text: $model.branch, prompt: Text(SettingsText.branchPlaceholder))
                    }
                    field(SettingsText.path) {
                        TextField(SettingsText.path, text: $model.path, prompt: Text(SettingsText.pathPlaceholder))
                    }
                    field(SettingsText.token) {
                        SecureField(SettingsText.token, text: $model.token, prompt: Text(SettingsText.tokenPlaceholder))
                    }
                    VStack(spacing: 10) {
                        Button { Task { await model.save() } } label: { Text(SettingsText.save).frame(maxWidth: .infinity) }
                            .buttonStyle(.pill())
                        Button { Task { await model.testConnection() } } label: { Text(SettingsText.testConnection).frame(maxWidth: .infinity) }
                            .buttonStyle(.pill(.secondary))
                        Button { Task { await model.upload() } } label: { Text(SettingsText.upload).frame(maxWidth: .infinity) }
                            .buttonStyle(.pill(.secondary))
                        Button(role: .destructive) { model.requestDownload() } label: { Text(SettingsText.download).frame(maxWidth: .infinity) }
                            .buttonStyle(.pill(.danger))
                            // Colgado del botón: en iOS 26 el diálogo sale como globo que apunta a su vista.
                            .confirmationDialog(SyncText.downloadTitle, isPresented: $model.isDownloadConfirmationPresented,
                                                titleVisibility: .visible) {
                                Button(SyncText.downloadConfirm, role: .destructive) { Task { await model.confirmDownload() } }
                                Button(SyncText.cancelLabel, role: .cancel) {}
                            } message: {
                                Text(SyncText.downloadWarning)
                            }
                    }
                }
                .card()
                Text(model.versionLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 4)
                    .accessibilityIdentifier("settings-version")
            }
            .padding(16)
        }
        .navigationTitle(SettingsText.title)
        .keyboardDismissal()
        .task { await model.load() }
    }

    /// Un campo de la PWA (`.input-group`): el nombre encima, en mayúsculas pequeñas, y la caja.
    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(Theme.textSecondary)
            content()
                .font(.system(size: 15))
                .foregroundStyle(Theme.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(Theme.input, in: .rect(cornerRadius: Theme.radiusSmall))
                .overlay { RoundedRectangle(cornerRadius: Theme.radiusSmall).strokeBorder(Theme.border) }
        }
    }

    private var statusText: String {
        switch model.status.state {
        case .disabled: SyncText.notConfigured.text
        case .ok: SyncText.synced.text
        case .pending: model.status.conflict ? SyncText.conflictTitle : SyncText.pendingChanges.text
        }
    }
}
