import Domain
import Presentation
import SwiftUI
import ViewModels

/// La entrada al catálogo al final de Progreso (`.catalog-card`): total y cuántos ejercicios no
/// tienen grupo.
struct CatalogCard: View {
    let model: CatalogModel

    var body: some View {
        NavigationLink {
            CatalogScreen(model: model)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(CatalogText.cardTitle).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
                        Spacer()
                        Text(CatalogText.total(model.total)).font(.system(size: 11)).foregroundStyle(Theme.textMuted)
                    }
                    HStack(spacing: 4) {
                        Text(CatalogText.cardSubtitle).foregroundStyle(Theme.textSecondary)
                        if model.withoutGroup > 0 {
                            Text(CatalogText.withoutGroup(model.withoutGroup)).fontWeight(.semibold).foregroundStyle(Theme.orange)
                        }
                    }
                    .font(.system(size: 12))
                }
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textMuted)
            }
            .card()
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("catalog-card")
    }
}

/// La lista del catálogo por grupos, con buscador, y el editor de cada ejercicio.
struct CatalogScreen: View {
    @Bindable var model: CatalogModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if model.sections.isEmpty {
                    Text(CatalogText.noMatches)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }
                ForEach(model.sections) { section in
                    HStack(spacing: 8) {
                        Text(section.title).foregroundStyle(Theme.textSecondary)
                        Text("\(section.rows.count)").fontWeight(.medium).foregroundStyle(Theme.textMuted)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .padding(.horizontal, 2)
                    .padding(.bottom, 6)
                    ForEach(section.rows) { row in
                        Button { model.edit(row.exerciseID) } label: {
                            HStack(spacing: 10) {
                                Text(row.name).font(.system(size: 15)).foregroundStyle(Theme.text).multilineTextAlignment(.leading)
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
                        .padding(.bottom, 6)
                    }
                    Spacer().frame(height: 12)
                }
            }
            .padding(16)
        }
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

/// Un grupo secundario (`.catalog-chip-ind`): píldora azul suave.
private struct CatalogChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
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
