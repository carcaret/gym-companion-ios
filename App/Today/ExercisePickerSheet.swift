import Domain
import Presentation
import SwiftUI
import ViewModels

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
            .searchable(text: $model.pickerQuery, prompt: FormText.searchExercise)
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
struct CreateExerciseForm: View {
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
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                ConfirmButton { Task { await model.createExercise() } }
                    .disabled(model.createName.trimmingWhitespace().isEmpty)
                    .accessibilityIdentifier("create-confirm")
            }
        }
        .onAppear { nameFocused = true }
    }
}
