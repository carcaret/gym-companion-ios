import Domain
import Presentation
import SwiftUI
import ViewModels

/// El entreno en curso: una tarjeta por ejercicio (acordeón), arrastrables para cambiar el orden,
/// deslizables para quitarlas (izquierda) o cambiarlas y saltarlas (derecha), y abajo terminar o
/// añadir.
struct ActiveWorkoutView: View {
    @Bindable var model: TodayModel

    var body: some View {
        List {
            ForEach(Array(model.activeCards.enumerated()), id: \.element.id) { index, card in
                ExerciseCardView(card: card, toggle: { model.toggleCard(card.exerciseID) }, actions: actions(index))
                    .cardRow()
                    // A la izquierda, quitar, como borrar en el historial. Sin `role: .destructive`:
                    // con ese rol la lista quita la fila antes de que se confirme.
                    .swipeActions(edge: .trailing) {
                        Button(card.removeLabel, systemImage: "trash") { Task { await model.requestRemoval(at: index) } }
                            .tint(Theme.actionRed)
                    }
                    // A la derecha, solo las opciones: deslizar del todo no ejecuta ninguna. Sin otro
                    // ejercicio en el catálogo, cambiar no se ofrece.
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        if model.canSwap {
                            Button(TodayText.swapLabel, systemImage: "arrow.left.arrow.right") { model.openSwapPicker(at: index) }
                                .tint(Theme.actionBlue)
                        }
                        Button(card.skipLabel, systemImage: card.isSkipped ? "arrow.uturn.backward" : "forward.end") {
                            Task { await model.toggleSkip(at: index) }
                        }
                        .tint(Theme.actionGray)
                    }
                    // Colgado de su tarjeta: en iOS 26 el diálogo sale como globo que apunta a su vista.
                    // `presenting` le pasa el aviso a la acción: SwiftUI lo cierra antes de ejecutarla.
                    .confirmationDialog(model.removalPrompt?.title ?? "", isPresented: Binding(presentedWhile: { model.removalPrompt?.exerciseID == card.exerciseID }, onDismiss: { model.cancelRemoval() }), titleVisibility: .visible, presenting: model.removalPrompt) { prompt in
                        Button(TodayText.removeConfirm, role: .destructive) { Task { await model.confirmRemoval(prompt) } }
                        Button(FormText.cancel, role: .cancel) { model.cancelRemoval() }
                    } message: { prompt in
                        Text(prompt.message)
                    }
            }
            .onMove { source, destination in
                guard let from = source.first else { return }
                Task { await model.moveCard(from: from, toOffset: destination) }
            }
        }
        .listStyle(.plain)
        // Las tarjetas se abren sin animación: en una `List` la animación las descuadraba.
        .environment(\.disclosureAnimates, false)
        .screenBackground()
        .keyboardDismissal()
        // El título dice la rutina («Entreno …») y el subtítulo, que está en curso (en la PWA, un
        // recuadro encima de las tarjetas) y si hay récord, con el trofeo plano de SF Symbols. En su
        // cápsula de la barra, el trofeo parecía un botón (repaso de la HIG, 2026-10-28).
        .navigationSubtitle(model.hasRecord
            ? Text("\(TodayText.inProgress) · \(Image(systemName: "trophy.fill")) \(TodayText.record)")
            : Text(TodayText.inProgress))
        .safeAreaInset(edge: .bottom) {
            BottomActions {
                Button { model.openAddPicker() } label: { Text(TodayText.addExercise).frame(maxWidth: .infinity) }
                    .buttonStyle(.glassPill(.secondary))
                    .accessibilityIdentifier(AccessibilityID.addExercise)
            } primary: {
                Button { Task { await model.finish() } } label: { Text(TodayText.finish).frame(maxWidth: .infinity) }
                    .buttonStyle(.glassPill())
                    .accessibilityIdentifier(AccessibilityID.finishWorkout)
            }
        }
        .sheet(isPresented: Binding(presentedWhile: { model.picker != nil }, onDismiss: { model.closePicker() })) {
            ExercisePickerSheet(model: model)
        }
        .alert(model.reciprocalOffer?.title ?? "", isPresented: Binding(presentedWhile: { model.reciprocalOffer != nil }, onDismiss: { model.declineReciprocal() }), presenting: model.reciprocalOffer) { offer in
            Button(TodayText.reciprocalDecline, role: .cancel) { model.declineReciprocal() }
            Button(offer.acceptLabel) { Task { await model.acceptReciprocal(offer) } }
        } message: { offer in
            Text(offer.message)
        }
    }

    private func actions(_ index: Int) -> ExerciseCardView.CardActions {
        ExerciseCardView.CardActions(
            adjust: { parameter, direction in Task { await model.adjust(parameter, direction: direction, at: index) } },
            type: { parameter, text in model.type(parameter, text: text, at: index) },
            commit: { Task { await model.commitTyping() } },
            focusSeries: { series in model.focusSeries(series, at: index) },
            chooseRep: { value, series in Task { await model.chooseRep(value, series: series, at: index) } }
        )
    }
}
