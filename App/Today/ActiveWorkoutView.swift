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
                Label(model.activeStatus, systemImage: "circle.fill")
                    .symbolEffect(.pulse)
                    .foregroundStyle(.green)
                    .font(.subheadline.weight(.semibold))
                    .listRowBackground(Color.clear)
            }
            ForEach(Array(model.activeCards.enumerated()), id: \.element.id) { index, card in
                ExerciseCardView(card: card, toggle: { model.toggleCard(card.exerciseID) }, actions: actions(index))
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .onMove { source, destination in
                guard let from = source.first else { return }
                // `onMove` da la posición antes de la que se suelta; `reorder` quiere la final.
                let to = destination > from ? destination - 1 : destination
                Task { await model.reorder(from: from, to: to) }
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("OK") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
            }
            ToolbarItem(placement: .topBarLeading) {
                if model.hasRecord { Image(systemName: "trophy.fill").foregroundStyle(.yellow).accessibilityLabel("Récord") }
            }
        }
        .safeAreaInset(edge: .bottom) {
            BottomActions {
                Button { model.openAddPicker() } label: { Label(TodayText.addExercise, systemImage: "plus") }
                    .buttonStyle(.bordered)
                    .fixedSize()
                    .accessibilityIdentifier("add-exercise")
            } primary: {
                Button { Task { await model.finish() } } label: { Text(TodayText.finish).frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("finish-workout")
            }
        }
        .sheet(isPresented: Binding(get: { model.picker != nil }, set: { if !$0 { model.closePicker() } })) {
            ExercisePickerSheet(model: model)
        }
        .confirmationDialog(model.removalPrompt?.title ?? "", isPresented: Binding(
            get: { model.removalPrompt != nil }, set: { if !$0 { model.cancelRemoval() } }
        ), titleVisibility: .visible) {
            Button(TodayText.removeConfirm, role: .destructive) { Task { await model.confirmRemoval() } }
            Button(TodayText.cancel, role: .cancel) { model.cancelRemoval() }
        } message: {
            Text(model.removalPrompt?.message ?? "")
        }
        .alert(model.reciprocalOffer?.title ?? "", isPresented: Binding(
            get: { model.reciprocalOffer != nil }, set: { if !$0 { model.declineReciprocal() } }
        )) {
            Button(TodayText.no, role: .cancel) { model.declineReciprocal() }
            Button(TodayText.yes) { Task { await model.acceptReciprocal() } }
        } message: {
            Text(model.reciprocalOffer?.message ?? "")
        }
    }

    private func actions(_ index: Int) -> ExerciseCardView.CardActions {
        ExerciseCardView.CardActions(
            adjust: { parameter, direction in Task { await model.adjust(parameter, direction: direction, at: index) } },
            set: { parameter, text in Task { await model.set(parameter, text: text, at: index) } },
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
