import Presentation
import SwiftUI
import ViewModels

/// Los ajustes de sincronización, un formulario de iOS en la hoja que abre el indicador: GitHub y
/// versión de la app. Solo pinta `SettingsModel`.
struct SettingsScreen: View {
    @Bindable var model: SettingsModel
    /// La tecla de retorno pasa al campo siguiente, como en un formulario de iOS; en el último
    /// cierra el teclado.
    @FocusState private var focused: Field?
    @Environment(\.dismiss) private var dismiss

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
                action(SettingsText.save, .saving) { Task { await model.save() } }
                    .disabled(!model.canSave)
                action(SettingsText.testConnection, .testing) { Task { await model.testConnection() } }
                    .disabled(!model.canTestConnection)
                // El resultado de la prueba, debajo de su botón (en la PWA, un aviso).
                if let result = model.connectionResult {
                    NoticeLabel(notice: result)
                        .accessibilityIdentifier("settings-connection-result")
                }
            }
            .listRowBackground(Theme.surface)
            Section {
                action(SettingsText.upload, .uploading) { Task { await model.upload() } }
                    .disabled(!model.canTransfer)
                action(SettingsText.download, .downloading, role: .destructive) { model.requestDownload() }
                    .disabled(!model.canTransfer)
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .close) { dismiss() }
                    .accessibilityIdentifier("settings-close")
            }
        }
        .interactiveDismissDisabled(model.hasUnsavedChanges)
        .screenBackground()
        .keyboardDismissal()
        .task { await model.load() }
    }

    /// Un botón del formulario; mientras hace lo suyo, una ruedita a la derecha (en la PWA, un aviso
    /// «Probando conexión...», «Subiendo...»).
    private func action(_ title: String, _ activity: SettingsModel.Activity, role: ButtonRole? = nil,
                        perform: @escaping () -> Void) -> some View {
        Button(role: role, action: perform) {
            HStack {
                Text(title)
                Spacer()
                if model.activity == activity { ProgressView() }
            }
        }
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
