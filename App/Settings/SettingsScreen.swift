import Application
import Domain
import Presentation
import SwiftUI
import ViewModels

/// La pestaña Ajustes: sincronización con GitHub y versión de la app. Solo pinta `SettingsModel`.
struct SettingsScreen: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Section {
                LabeledContent(SettingsText.status) { Text(statusText).foregroundStyle(.secondary) }
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
            } header: {
                Text(SettingsText.githubSection)
            }
            Section {
                Button(SettingsText.save) { Task { await model.save() } }
                Button(SettingsText.testConnection) { Task { await model.testConnection() } }
                Button(SettingsText.upload) { Task { await model.upload() } }
                Button(SettingsText.download, role: .destructive) { model.requestDownload() }
            }
            Section(SettingsText.aboutSection) {
                Text(model.versionLabel).foregroundStyle(.secondary).accessibilityIdentifier("settings-version")
            }
        }
        .navigationTitle(SettingsText.title)
        .task { await model.load() }
        .confirmationDialog(SyncText.downloadTitle, isPresented: $model.isDownloadConfirmationPresented, titleVisibility: .visible) {
            Button(SyncText.downloadConfirm, role: .destructive) { Task { await model.confirmDownload() } }
            Button(SyncText.cancelLabel, role: .cancel) {}
        } message: {
            Text(SyncText.downloadWarning)
        }
    }

    /// Un campo con su nombre a la izquierda: con el campo relleno, el texto de ayuda ya no se ve.
    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        LabeledContent(label) {
            content()
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
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
