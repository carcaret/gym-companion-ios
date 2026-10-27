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
                            .tint(Theme.red)
                    }
                    // A la derecha, solo las opciones: deslizar del todo no ejecuta ninguna. Sin otro
                    // ejercicio en el catálogo, cambiar no se ofrece.
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        if model.canSwap {
                            Button(TodayText.swapLabel, systemImage: "arrow.left.arrow.right") { model.openSwapPicker(at: index) }
                                .tint(Theme.accent)
                        }
                        Button(card.skipLabel, systemImage: card.isSkipped ? "arrow.uturn.backward" : "forward.end") {
                            Task { await model.toggleSkip(at: index) }
                        }
                        .tint(Theme.textMuted)
                    }
                    // Colgado de su tarjeta: en iOS 26 el diálogo sale como globo que apunta a su vista.
                    // `presenting` le pasa el aviso a la acción: SwiftUI lo cierra antes de ejecutarla.
                    .confirmationDialog(model.removalPrompt?.title ?? "", isPresented: Binding(
                        get: { model.removalPrompt?.exerciseID == card.exerciseID }, set: { if !$0 { model.cancelRemoval() } }
                    ), titleVisibility: .visible, presenting: model.removalPrompt) { prompt in
                        Button(TodayText.removeConfirm, role: .destructive) { Task { await model.confirmRemoval(prompt) } }
                        Button(TodayText.cancel, role: .cancel) { model.cancelRemoval() }
                    } message: { prompt in
                        Text(prompt.message)
                    }
            }
            .onMove { source, destination in
                guard let from = source.first else { return }
                // `onMove` da la posición antes de la que se suelta; `reorder` quiere la final.
                let to = destination > from ? destination - 1 : destination
                Task { await model.reorder(from: from, to: to) }
            }
        }
        .listStyle(.plain)
        // Las tarjetas se abren sin animación: en una `List` la animación las descuadraba.
        .environment(\.disclosureAnimates, false)
        .screenBackground()
        .keyboardDismissal()
        // El título dice la rutina («Entreno …») y el subtítulo, que está en curso (en la PWA, un
        // recuadro encima de las tarjetas).
        .navigationSubtitle(TodayText.inProgress)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if model.hasRecord { Image(systemName: "trophy.fill").foregroundStyle(Theme.gold).accessibilityLabel("Récord") }
            }
        }
        .safeAreaInset(edge: .bottom) {
            BottomActions {
                Button { model.openAddPicker() } label: { Label(TodayText.addExercise, systemImage: "plus") }
                    .buttonStyle(.glassPill(.secondary))
                    .fixedSize()
                    .accessibilityIdentifier("add-exercise")
            } primary: {
                Button { Task { await model.finish() } } label: { Text(TodayText.finish).frame(maxWidth: .infinity) }
                    .buttonStyle(.glassPill())
                    .accessibilityIdentifier("finish-workout")
            }
        }
        .sheet(isPresented: Binding(get: { model.picker != nil }, set: { if !$0 { model.closePicker() } })) {
            ExercisePickerSheet(model: model)
        }
        .alert(model.reciprocalOffer?.title ?? "", isPresented: Binding(
            get: { model.reciprocalOffer != nil }, set: { if !$0 { model.declineReciprocal() } }
        ), presenting: model.reciprocalOffer) { offer in
            Button(TodayText.no, role: .cancel) { model.declineReciprocal() }
            Button(TodayText.yes) { Task { await model.acceptReciprocal(offer) } }
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

/// Elegir un ejercicio para añadir o cambiar: una hoja con búsqueda y, al cambiar, una sección para
/// el grupo del ejercicio y otra para el resto. Al añadir, además, "Solo esta sesión" y crear uno
/// nuevo.
struct ExercisePickerSheet: View {
    @Bindable var model: TodayModel

    var body: some View {
        NavigationStack {
            List {
                if let picker = model.picker {
                    if picker.offersOneOff {
                        Toggle(TodayText.oneOffToggle, isOn: Binding(get: { picker.isOneOff }, set: { _ in model.toggleOneOff() }))
                            .accessibilityIdentifier("one-off-toggle")
                    }
                    ForEach(picker.sections, id: \.title) { section in
                        Section {
                            ForEach(section.rows) { row in
                                Button { Task { await model.choose(row.id) } } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(row.exercise.name)
                                        if let detail = row.detail {
                                            Text(detail).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                                        }
                                    }
                                }
                                .foregroundStyle(.primary)
                            }
                        } header: {
                            if let title = section.title { Text(title) }
                        }
                    }
                    if picker.canCreate {
                        Button(TodayText.createExercise) { model.openCreate() }
                        .accessibilityIdentifier("create-exercise")
                    }
                }
            }
            .searchable(text: $model.pickerQuery, prompt: TodayText.searchPlaceholder)
            .screenBackground()
            .navigationTitle(model.picker?.title ?? "")
            .navigationSubtitle(model.picker?.subtitle ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(TodayText.close) { model.closePicker() } }
            }
            .alert(TodayText.createTitle, isPresented: $model.isCreatePresented) {
                TextField(TodayText.createNamePlaceholder, text: $model.createName)
                Button(TodayText.cancel, role: .cancel) {}
                Button(TodayText.createConfirm) { Task { await model.createExercise() } }
            } message: {
                Text(model.createMessage ?? TodayText.createNameLabel)
            }
        }
        .presentationDetents([.medium, .large])
    }
}
