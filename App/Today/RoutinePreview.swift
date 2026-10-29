import Domain
import Presentation
import SwiftUI
import ViewModels

/// La vista previa de una rutina, empujada sobre el selector.
struct RoutinePreview: View {
    @Bindable var model: TodayModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(Array(model.previewCards.enumerated()), id: \.offset) { index, card in
                    ExerciseCardView(card: card, toggle: { model.togglePreviewCard(index) })
                }
            }
            .padding()
        }
        // Sin ejercicios (la primera vez): qué hacer, en vez de una pantalla en blanco.
        .overlay {
            if model.isPreviewEmpty {
                ContentUnavailableView(TodayText.emptyRoutineTitle, systemImage: "dumbbell",
                                       description: Text(TodayText.emptyRoutineMessage))
            }
        }
        .safeAreaInset(edge: .bottom) {
            BottomActions(primary: {
                Button { Task { await model.requestStart() } } label: { Text(TodayText.start).frame(maxWidth: .infinity) }
                    .buttonStyle(.glassPill())
                    .accessibilityIdentifier("start-workout")
                    // Colgado del botón: en iOS 26 el diálogo sale como globo que apunta a su vista.
                    // `presenting` le pasa el aviso a la acción: SwiftUI lo cierra antes.
                    .confirmationDialog(model.replacePrompt?.title ?? "", isPresented: Binding(
                        get: { model.replacePrompt != nil }, set: { if !$0 { model.cancelReplace() } }
                    ), titleVisibility: .visible, presenting: model.replacePrompt) { prompt in
                        Button(TodayText.replaceConfirm, role: .destructive) { Task { await model.confirmReplace(prompt) } }
                        Button(FormText.cancel, role: .cancel) { model.cancelReplace() }
                    } message: { prompt in
                        Text(prompt.message)
                    }
            })
        }
    }
}
