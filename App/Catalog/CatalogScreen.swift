import Domain
import Presentation
import SwiftUI
import ViewModels

/// El catálogo, empujado con valor desde Progreso para que tocar otra vez la pestaña lo cierre.
struct CatalogRoute: Hashable {}

/// La lista del catálogo por grupos, con buscador, y el editor de cada ejercicio. Una `List` de
/// iOS con sus filas y sus secciones (cada una con su número de ejercicios), con los colores de la
/// app, como Gráficas y Ajustes; antes eran las filas tarjeta de la PWA (2026-10-27).
struct CatalogScreen: View {
    @Bindable var model: CatalogModel

    var body: some View {
        List {
            ForEach(model.sections) { section in
                Section {
                    ForEach(section.rows) { row in
                        Button { model.edit(row.exerciseID) } label: {
                            HStack(spacing: 10) {
                                Text(row.name).foregroundStyle(Theme.text).multilineTextAlignment(.leading)
                                Spacer()
                                ForEach(row.secondaries, id: \.self) { secondary in
                                    CatalogChip(text: secondary)
                                }
                            }
                            .contentShape(.rect)
                        }
                        .listRowBackground(Theme.surface)
                    }
                } header: {
                    HStack(spacing: 6) {
                        Text(section.title)
                        Text("\(section.rows.count)").foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
        .overlay {
            if model.sections.isEmpty {
                if model.query.isEmpty {
                    ContentUnavailableView(CatalogText.empty, systemImage: "dumbbell")
                } else {
                    ContentUnavailableView.search(text: model.query)
                }
            }
        }
        .searchable(text: $model.query, prompt: CatalogText.searchPlaceholder)
        .navigationTitle(CatalogText.title)
        // Lo que decía la tarjeta de Progreso: el total y los que no tienen grupo.
        .navigationSubtitle(model.summary)
        .screenBackground()
        .keyboardDismissal()
        .onDisappear { model.leave() }
        .sheet(isPresented: Binding(get: { model.editor != nil }, set: { if !$0 { model.cancelEditing() } })) {
            CatalogEditor(model: model)
        }
    }
}

/// Un grupo secundario (`.catalog-chip-ind`): píldora azul suave.
private struct CatalogChip: View {
    let text: String

    var body: some View {
        Text(text)
            .scaledFont(11, .semibold)
            .foregroundStyle(Theme.accentLight)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(Theme.accent.opacity(0.12), in: .capsule)
            .overlay { Capsule().strokeBorder(Theme.accent.opacity(0.28)) }
    }
}

private struct CatalogEditor: View {
    @Bindable var model: CatalogModel

    var body: some View {
        NavigationStack {
            Form {
                Section(CatalogText.nameLabel) {
                    TextField(CatalogText.nameLabel, text: Binding(get: { model.editor?.name ?? "" }, set: { model.editor?.name = $0 }))
                }
                Section(CatalogText.groupLabel) {
                    Picker(CatalogText.groupLabel, selection: Binding(get: { model.editor?.group }, set: { model.setGroup($0) })) {
                        Text(CatalogText.noGroup).tag(MuscleGroup?.none)
                        ForEach(MuscleGroup.all, id: \.self) { group in
                            Text(GroupText.name(group)).tag(MuscleGroup?.some(group))
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section {
                    ForEach(model.chips) { chip in
                        Toggle(chip.title, isOn: Binding(get: { chip.isOn }, set: { _ in model.toggleSecondary(chip.group) }))
                            .disabled(!chip.isEnabled)
                    }
                } header: {
                    Text(CatalogText.secondaryLabel)
                } footer: {
                    Text(CatalogText.secondaryHint)
                }
            }
            .navigationTitle(CatalogText.editorTitle)
            .interactiveDismissDisabled(model.hasChanges)
            .screenBackground()
            .keyboardDismissal()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // ✕ y ✓ de iOS 26, como todas las hojas de la app (decisión del usuario, 2026-10-28).
                ToolbarItem(placement: .cancellationAction) {
                    // Con cambios, pregunta antes de tirarlos, como las demás hojas.
                    Button(role: .close) { model.requestCancel() }
                        .accessibilityIdentifier("catalog-cancel")
                        .confirmationDialog(FormText.discardTitle, isPresented: $model.isDiscardPromptPresented,
                                            titleVisibility: .visible) {
                            Button(FormText.discardConfirm, role: .destructive) { model.discardChanges() }
                            Button(SyncText.cancelLabel, role: .cancel) { model.keepEditing() }
                        }
                }
                ToolbarItem(placement: .confirmationAction) {
                    ConfirmButton { Task { await model.save() } }
                        .disabled(!model.canSave)
                }
            }
        }
    }
}
