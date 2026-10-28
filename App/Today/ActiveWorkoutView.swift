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
        // recuadro encima de las tarjetas) y si hay récord, con el trofeo plano de SF Symbols. En su
        // cápsula de la barra, el trofeo parecía un botón (repaso de la HIG, 2026-10-28).
        .navigationSubtitle(model.hasRecord
            ? Text("\(TodayText.inProgress) · \(Image(systemName: "trophy.fill")) \(TodayText.record)")
            : Text(TodayText.inProgress))
        .safeAreaInset(edge: .bottom) {
            BottomActions {
                Button { model.openAddPicker() } label: { Text(TodayText.addExercise).frame(maxWidth: .infinity) }
                    .buttonStyle(.glassPill(.secondary))
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

/// Elegir un ejercicio para añadir o cambiar: una hoja con búsqueda y, al cambiar, una sección para
/// el grupo del ejercicio y otra para el resto. Al añadir, además, "Solo esta sesión" y crear uno
/// nuevo.
struct ExercisePickerSheet: View {
    @Bindable var model: TodayModel

    var body: some View {
        AppNavigationStack {
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
                    // Con algo buscado que no existe, se crea de un toque; sin búsqueda, en su pantalla
                    // (repaso de la HIG, 2026-10-28: antes, una alerta con un campo).
                    if let label = picker.searchCreateLabel {
                        Button(label) { Task { await model.createFromSearch() } }
                            .accessibilityIdentifier("create-from-search")
                    } else if picker.offersNewExercise {
                        Button(TodayText.createExercise) { model.openCreate() }
                            .accessibilityIdentifier("create-exercise")
                    }
                }
            }
            .searchable(text: $model.pickerQuery, prompt: TodayText.searchPlaceholder)
            .screenBackground()
            .keyboardDismissal()
            .navigationTitle(model.picker?.title ?? "")
            .navigationSubtitle(model.picker?.subtitle ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Solo para elegir: la ✕ de iOS 26, sin ✓.
                ToolbarItem(placement: .cancellationAction) { Button(role: .close) { model.closePicker() } }
            }
            .navigationDestination(isPresented: $model.isCreatePresented) { CreateExerciseForm(model: model) }
        }
        // Siempre grande: a media altura, al cerrarse el teclado la hoja se encogía, la fila se
        // movía bajo el dedo e iOS cancelaba el toque (vídeo del CI y el iPhone, 2026-10-27).
    }
}

/// Crear un ejercicio nuevo sin nada buscado, empujado en el selector: el nombre y el grupo, como el
/// editor del catálogo. Se vuelve con la flecha; la ✓ lo crea y lo añade.
private struct CreateExerciseForm: View {
    @Bindable var model: TodayModel
    @FocusState private var nameFocused: Bool

    var body: some View {
        Form {
            Section {
                TextField(TodayText.createNamePlaceholder, text: $model.createName)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit { Task { await model.createExercise() } }
                    .accessibilityIdentifier("create-name")
            } header: {
                Text(TodayText.createNameLabel)
            } footer: {
                // Ya existe: lo dice aquí, debajo del nombre.
                if let message = model.createMessage { Text(message).foregroundStyle(Theme.gold) }
            }
            Section(CatalogText.groupLabel) {
                Picker(CatalogText.groupLabel, selection: $model.createGroup) {
                    Text(CatalogText.noGroup).tag(MuscleGroup?.none)
                    ForEach(MuscleGroup.all, id: \.self) { group in
                        Text(GroupText.name(group)).tag(MuscleGroup?.some(group))
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .screenBackground()
        .keyboardDismissal()
        .navigationTitle(TodayText.createTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm) { Task { await model.createExercise() } }
                    .confirmTint()
                    .disabled(model.createName.trimmingWhitespace().isEmpty)
                    .accessibilityIdentifier("create-confirm")
            }
        }
        .onAppear { nameFocused = true }
    }
}
