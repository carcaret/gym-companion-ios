import Domain
import Presentation
import SwiftUI
import ViewModels

/// El entreno en curso: una tarjeta por ejercicio (acordeón), arrastrables para cambiar el orden,
/// y abajo terminar o añadir.
struct ActiveWorkoutView: View {
    @Bindable var model: TodayModel

    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    Image(systemName: "circle.fill").font(.system(size: 10)).foregroundStyle(Theme.green).symbolEffect(.pulse)
                    Text(model.activeStatus).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.text)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Theme.accentTint, in: .rect(cornerRadius: Theme.radiusSmall))
                .overlay { RoundedRectangle(cornerRadius: Theme.radiusSmall).strokeBorder(Theme.accent.opacity(0.22)) }
                .cardRow()
            }
            ForEach(Array(model.activeCards.enumerated()), id: \.element.id) { index, card in
                ExerciseCardView(card: card, toggle: { model.toggleCard(card.exerciseID) }, actions: actions(index))
                    .cardRow()
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
        .screenBackground()
        .numberPadDismissal()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if model.hasRecord { Image(systemName: "trophy.fill").foregroundStyle(Theme.gold).accessibilityLabel("Récord") }
            }
        }
        .safeAreaInset(edge: .bottom) {
            BottomActions {
                Button { model.openAddPicker() } label: { Label(TodayText.addExercise, systemImage: "plus") }
                    .buttonStyle(.pill(.subtle))
                    .fixedSize()
                    .accessibilityIdentifier("add-exercise")
            } primary: {
                Button { Task { await model.finish() } } label: { Text(TodayText.finish).frame(maxWidth: .infinity) }
                    .buttonStyle(.pill())
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
            chooseRep: { value, series in Task { await model.chooseRep(value, series: series, at: index) } },
            swap: { model.openSwapPicker(at: index) },
            toggleSkip: { Task { await model.toggleSkip(at: index) } },
            remove: { Task { await model.requestRemoval(at: index) } }
        )
    }
}

/// Elegir un ejercicio para añadir o cambiar, con búsqueda, el chip "Solo esta sesión" y crear uno
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
                    ForEach(picker.exercises, id: \.id) { exercise in
                        Button { Task { await model.choose(exercise.id) } } label: {
                            HStack {
                                Text(exercise.name)
                                Spacer()
                                Image(systemName: "plus.circle").foregroundStyle(.tint)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                    if picker.canCreate {
                        Button(TodayText.createExercise) {
                            model.createName = ""
                            model.isCreatePresented = true
                        }
                        .accessibilityIdentifier("create-exercise")
                    }
                }
            }
            .searchable(text: $model.pickerQuery, prompt: TodayText.searchPlaceholder)
            .screenBackground()
            .navigationTitle(model.picker?.title ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(TodayText.close) { model.closePicker() } }
            }
            .alert(TodayText.createTitle, isPresented: $model.isCreatePresented) {
                TextField(TodayText.createNamePlaceholder, text: $model.createName)
                Button(TodayText.cancel, role: .cancel) {}
                Button(TodayText.createConfirm) { Task { await model.createExercise() } }
            } message: {
                Text(TodayText.createNameLabel)
            }
        }
        .presentationDetents([.medium, .large])
    }
}
