import Domain
import Presentation
import SwiftUI
import ViewModels

/// La entrada al catálogo al final de Progreso: total y cuántos ejercicios no tienen grupo.
struct CatalogCard: View {
    let model: CatalogModel

    var body: some View {
        NavigationLink {
            CatalogScreen(model: model)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(CatalogText.cardTitle).font(.headline)
                    Spacer()
                    Text(CatalogText.total(model.total)).font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    Text(CatalogText.cardSubtitle).font(.subheadline).foregroundStyle(.secondary)
                    if model.withoutGroup > 0 {
                        Text(CatalogText.withoutGroup(model.withoutGroup)).font(.caption.weight(.semibold)).foregroundStyle(.orange)
                    }
                }
            }
        }
        .accessibilityIdentifier("catalog-card")
    }
}

/// La lista del catálogo por grupos, con buscador, y el editor de cada ejercicio.
struct CatalogScreen: View {
    @Bindable var model: CatalogModel

    var body: some View {
        List {
            if model.sections.isEmpty {
                Text(CatalogText.noMatches).foregroundStyle(.secondary)
            }
            ForEach(model.sections) { section in
                Section {
                    ForEach(section.rows) { row in
                        Button { model.edit(row.exerciseID) } label: {
                            HStack {
                                Text(row.name)
                                Spacer()
                                ForEach(row.secondaries, id: \.self) { secondary in
                                    Text(secondary).font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(.blue.opacity(0.15), in: .capsule)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                } header: {
                    HStack { Text(section.title); Text("\(section.rows.count)").foregroundStyle(.secondary) }
                }
            }
        }
        .searchable(text: $model.query, prompt: CatalogText.searchPlaceholder)
        .navigationTitle(CatalogText.title)
        .onDisappear { model.leave() }
        .sheet(isPresented: Binding(get: { model.editor != nil }, set: { if !$0 { model.cancelEditing() } })) {
            CatalogEditor(model: model)
        }
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(CatalogText.cancel) { model.cancelEditing() } }
                ToolbarItem(placement: .confirmationAction) { Button(CatalogText.save) { Task { await model.save() } } }
            }
        }
    }
}
