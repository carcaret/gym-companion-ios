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
                TextField(SettingsText.repository, text: $model.repository, prompt: Text(SettingsText.repositoryPlaceholder))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityIdentifier("settings-repository")
                TextField(SettingsText.branch, text: $model.branch, prompt: Text(SettingsText.branchPlaceholder))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField(SettingsText.path, text: $model.path, prompt: Text(SettingsText.pathPlaceholder))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField(SettingsText.token, text: $model.token, prompt: Text(SettingsText.tokenPlaceholder))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
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

    private var statusText: String {
        switch model.status.state {
        case .disabled: SyncText.notConfigured.text
        case .ok: SyncText.synced.text
        case .pending: model.status.conflict ? SyncText.conflictTitle : SyncText.pendingChanges.text
        }
    }
}
