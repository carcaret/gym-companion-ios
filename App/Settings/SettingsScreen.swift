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

    /// En el orden en que se ven: la tecla de retorno pasa al siguiente.
    private enum Field: CaseIterable {
        case repository, token, branch, path
    }

    var body: some View {
        Form {
            Section(SettingsText.githubSection) {
                LabeledContent(SettingsText.status, value: model.statusText)
                field(SettingsText.repository, .repository) {
                    TextField(SettingsText.repository, text: $model.repository, prompt: Text(SettingsText.repositoryPlaceholder))
                        .accessibilityIdentifier("settings-repository")
                }
                field(SettingsText.token, .token) {
                    // Sin `textContentType(.password)`: no es una contraseña, y iOS ofrecía
                    // guardarla en Contraseñas (2026-10-27).
                    SecureField(SettingsText.token, text: $model.token, prompt: Text(SettingsText.tokenPlaceholder))
                        .accessibilityIdentifier("settings-token")
                }
                // Por qué no se guardó (la conexión falló), debajo de los campos.
                if let result = model.connectionResult {
                    NoticeLabel(notice: result)
                        .accessibilityIdentifier("settings-connection-result")
                }
            }
            .listRowBackground(Theme.surface)
            Section {
                field(SettingsText.branch, .branch) {
                    TextField(SettingsText.branch, text: $model.branch, prompt: Text(SettingsText.branchPlaceholder))
                        .accessibilityIdentifier("settings-branch")
                }
                field(SettingsText.path, .path) {
                    TextField(SettingsText.path, text: $model.path, prompt: Text(SettingsText.pathPlaceholder))
                        .accessibilityIdentifier("settings-path")
                }
                Button(role: .destructive) { model.requestDownload() } label: {
                    HStack {
                        Text(SettingsText.download)
                        Spacer()
                        if model.activity == .downloading { ProgressView() }
                    }
                }
                .disabled(!model.canDownload)
                // Colgado del botón: en iOS 26 el diálogo sale como globo que apunta a su vista.
                .confirmationDialog(SyncText.downloadTitle, isPresented: $model.isDownloadConfirmationPresented,
                                    titleVisibility: .visible) {
                    Button(SyncText.downloadConfirm, role: .destructive) { Task { await model.confirmDownload() } }
                    Button(FormText.cancel, role: .cancel) {}
                } message: {
                    Text(SyncText.downloadWarning)
                }
            } header: {
                Text(SettingsText.advancedSection)
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
            ToolbarItem(placement: .cancellationAction) {
                // Con algo escrito sin guardar, pregunta antes de tirarlo (antes lo tiraba).
                Button(role: .close) { model.requestClose() }
                    .accessibilityIdentifier("settings-close")
                    .discardChangesDialog(isPresented: model.isDiscardPromptPresented,
                                          discard: model.discardChanges, keep: model.keepEditing)
            }
            ToolbarItem(placement: .confirmationAction) {
                // Prueba la conexión y, si va bien, guarda y cierra (como al añadir una cuenta).
                if model.activity == .saving {
                    ProgressView()
                } else {
                    ConfirmButton { Task { await model.save() } }
                        .disabled(!model.canSave)
                        .accessibilityIdentifier("settings-save")
                }
            }
        }
        .interactiveDismissDisabled(model.hasUnsavedChanges)
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
