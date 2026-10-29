import Domain
import Presentation
import SwiftUI
import ViewModels

/// La hoja de editar una sesión: la ✕ y la ✓, y con cambios no se cierra deslizando.
struct SessionEditor: View {
    @Bindable var model: HistoryModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) { SessionCards(model: model) }
                .padding()
        }
        .keyboardDismissal()
        .screenBackground()
        .navigationTitle(model.detailTitle)
        .navigationSubtitle(model.detailSubtitle)
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(model.hasChanges)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                // ✕ y ✓ de iOS 26, como todas las hojas de la app (decisión del usuario, 2026-10-28).
                Button(role: .close) { model.requestClose() }
                    .accessibilityIdentifier("session-cancel")
                    // Colgado de la ✕: en iOS 26 el diálogo sale como globo que apunta a su vista, y
                    // se cierra tocando fuera (sigue editando).
                    .confirmationDialog(HistoryText.discardTitle, isPresented: Binding(
                        get: { model.isDiscardPromptPresented }, set: { if !$0 { model.keepEditing() } }
                    ), titleVisibility: .visible) {
                        Button(FormText.discardConfirm, role: .destructive) { model.discardChanges() }
                        Button(FormText.keepEditing, role: .cancel) { model.keepEditing() }
                    }
            }
            ToolbarItem(placement: .confirmationAction) {
                ConfirmButton { Task { await model.finishEditing() } }
                    .disabled(!model.hasChanges)
                    .accessibilityIdentifier("session-done")
            }
        }
    }
}
