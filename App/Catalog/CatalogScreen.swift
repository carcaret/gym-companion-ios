import Domain
import Presentation
import SwiftUI
import ViewModels

/// El catálogo, empujado con valor desde Progreso para que tocar otra vez la pestaña lo cierre.
struct CatalogRoute: Hashable {}

/// La entrada al catálogo al final de Progreso (`.catalog-card`): total y cuántos ejercicios no
/// tienen grupo.
struct CatalogCard: View {
    let model: CatalogModel

    var body: some View {
        NavigationLink(value: CatalogRoute()) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(CatalogText.cardTitle).scaledFont(15, .semibold).foregroundStyle(Theme.text)
                        Spacer()
                        Text(CatalogText.total(model.total)).scaledFont(11).foregroundStyle(Theme.textMuted)
                    }
                    HStack(spacing: 4) {
                        Text(CatalogText.cardSubtitle).foregroundStyle(Theme.textSecondary)
                        if model.withoutGroup > 0 {
                            Text(CatalogText.withoutGroup(model.withoutGroup)).fontWeight(.semibold).foregroundStyle(Theme.orange)
                        }
                    }
                    .scaledFont(12)
                }
                Image(systemName: "chevron.right").scaledFont(13, .semibold).foregroundStyle(Theme.textMuted)
            }
            .card()
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("catalog-card")
    }
}

/// La lista del catálogo por grupos, con buscador, y el editor de cada ejercicio. Una `List` de
/// iOS con secciones, con las filas y las cabeceras de la PWA.
struct CatalogScreen: View {
    @Bindable var model: CatalogModel

    var body: some View {
        List {
            if model.sections.isEmpty {
                Text(CatalogText.noMatches)
                    .scaledFont(14)
                    .foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .catalogRow()
            }
            ForEach(model.sections) { section in
                Section {
                    ForEach(section.rows) { row in
                        Button { model.edit(row.exerciseID) } label: {
                            HStack(spacing: 10) {
                                Text(row.name).scaledFont(15).foregroundStyle(Theme.text).multilineTextAlignment(.leading)
                                Spacer()
                                ForEach(row.secondaries, id: \.self) { secondary in
                                    CatalogChip(text: secondary)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Theme.surface, in: .rect(cornerRadius: Theme.radiusSmall))
                            .overlay { RoundedRectangle(cornerRadius: Theme.radiusSmall).strokeBorder(Theme.borderLight) }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .catalogRow()
                    }
                } header: {
                    HStack(spacing: 8) {
                        Text(section.title).foregroundStyle(Theme.textSecondary)
                        Text("\(section.rows.count)").fontWeight(.medium).foregroundStyle(Theme.textMuted)
                    }
                    .scaledFont(12, .semibold)
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .padding(.horizontal, 2)
                    .padding(.top, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 6, trailing: 16))
                    // La cabecera se queda fija arriba al desplazar: con el fondo de la pantalla.
                    .background(Theme.background)
                }
                .listSectionSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .contentMargins(.bottom, 16, for: .scrollContent)
        .searchable(text: $model.query, prompt: CatalogText.searchPlaceholder)
        .navigationTitle(CatalogText.title)
        .screenBackground()
        .keyboardDismissal()
        .onDisappear { model.leave() }
        .sheet(isPresented: Binding(get: { model.editor != nil }, set: { if !$0 { model.cancelEditing() } })) {
            CatalogEditor(model: model)
        }
    }
}

private extension View {
    /// Una fila del catálogo: sin fondo ni separador, con 6 px entre filas, como en la PWA.
    func catalogRow() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
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
            .screenBackground()
            .keyboardDismissal()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(CatalogText.cancel) { model.cancelEditing() } }
                ToolbarItem(placement: .confirmationAction) { Button(CatalogText.save) { Task { await model.save() } } }
            }
        }
    }
}
