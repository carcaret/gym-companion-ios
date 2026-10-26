import Presentation
import SwiftUI
import ViewModels

/// La pestaña Ajustes, un formulario de iOS: sincronización con GitHub y versión de la app. Solo
/// pinta `SettingsModel`.
struct SettingsScreen: View {
    @Bindable var model: SettingsModel
    /// La tecla de retorno pasa al campo siguiente, como en un formulario de iOS; en el último
    /// cierra el teclado.
    @FocusState private var focused: Field?

    private enum Field: CaseIterable {
        case repository, branch, path, token
    }

    var body: some View {
        Form {
            Section(SettingsText.githubSection) {
                LabeledContent(SettingsText.status, value: model.statusText)
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
            }
            .listRowBackground(Theme.surface)
            Section {
                Button(SettingsText.save) { Task { await model.save() } }
                Button(SettingsText.testConnection) { Task { await model.testConnection() } }
            }
            .listRowBackground(Theme.surface)
            Section {
                Button(SettingsText.upload) { Task { await model.upload() } }
                Button(SettingsText.download, role: .destructive) { model.requestDownload() }
                    // Colgado del botón: en iOS 26 el diálogo sale como globo que apunta a su vista.
                    .confirmationDialog(SyncText.downloadTitle, isPresented: $model.isDownloadConfirmationPresented,
                                        titleVisibility: .visible) {
                        Button(SyncText.downloadConfirm, role: .destructive) { Task { await model.confirmDownload() } }
                        Button(SyncText.cancelLabel, role: .cancel) {}
                    } message: {
                        Text(SyncText.downloadWarning)
                    }
            } footer: {
                Text(model.versionLabel)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .accessibilityIdentifier("settings-version")
            }
            .listRowBackground(Theme.surface)
        }
        .navigationTitle(SettingsText.title)
        .screenBackground()
        .keyboardDismissal()
        .task { await model.load() }
    }

    /// Una fila del formulario: el nombre a la izquierda y lo escrito a la derecha, como en los
    /// formularios de iOS.
    private func field<Content: View>(_ label: String, _ id: Field, @ViewBuilder content: () -> Content) -> some View {
        LabeledContent(label) {
            content()
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused, equals: id)
                .submitLabel(id == Field.allCases.last ? .done : .next)
                .onSubmit { focused = Field.allCases.drop(while: { $0 != id }).dropFirst().first }
        }
    }
}
