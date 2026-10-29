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
                    .accessibilityIdentifier(AccessibilityID.sessionCancel)
                    .discardChangesDialog(HistoryText.discardTitle, isPresented: model.isDiscardPromptPresented,
                                          discard: model.discardChanges, keep: model.keepEditing)
            }
            ToolbarItem(placement: .confirmationAction) {
                ConfirmButton { Task { await model.finishEditing() } }
                    .disabled(!model.hasChanges)
                    .accessibilityIdentifier(AccessibilityID.sessionDone)
            }
        }
    }
}
