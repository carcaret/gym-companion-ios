import Domain
import Presentation
import SwiftUI
import ViewModels

/// La pestaña Ajustes: sincronización con GitHub y versión de la app. Solo pinta `SettingsModel`.
struct SettingsScreen: View {
    @Bindable var model: SettingsModel
    /// La tecla de retorno pasa al campo siguiente, como en un formulario de iOS; en el último
    /// cierra el teclado.
    @FocusState private var focused: Field?

    private enum Field: CaseIterable {
        case repository, branch, path, token
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(SettingsText.githubSection).scaledFont(16, .bold).foregroundStyle(Theme.text)
                    HStack {
                        Text(SettingsText.status).foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text(model.statusText).foregroundStyle(Theme.text)
                    }
                    .scaledFont(14)
                    field(SettingsText.repository, .repository) {
                        TextField(SettingsText.repository, text: $model.repository, prompt: Text(SettingsText.repositoryPlaceholder))
                            .accessibilityIdentifier("settings-repository")
                    }
                    field(SettingsText.branch, .branch) {
                        TextField(SettingsText.branch, text: $model.branch, prompt: Text(SettingsText.branchPlaceholder))
                            .accessibilityIdentifier("settings-branch")
                    }
                    field(SettingsText.path, .path) {
                        TextField(SettingsText.path, text: $model.path, prompt: Text(SettingsText.pathPlaceholder))
                            .accessibilityIdentifier("settings-path")
                    }
                    field(SettingsText.token, .token) {
                        SecureField(SettingsText.token, text: $model.token, prompt: Text(SettingsText.tokenPlaceholder))
                            .textContentType(.password)
                            .accessibilityIdentifier("settings-token")
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
                    .scaledFont(11)
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
    private func field<Content: View>(_ label: String, _ id: Field, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .scaledFont(12, .semibold)
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(Theme.textSecondary)
            content()
                .scaledFont(15)
                .foregroundStyle(Theme.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused, equals: id)
                .submitLabel(id == Field.allCases.last ? .done : .next)
                .onSubmit { focused = Field.allCases.drop(while: { $0 != id }).dropFirst().first }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(Theme.input, in: .rect(cornerRadius: Theme.radiusSmall))
                .overlay { RoundedRectangle(cornerRadius: Theme.radiusSmall).strokeBorder(Theme.border) }
        }
    }
}
