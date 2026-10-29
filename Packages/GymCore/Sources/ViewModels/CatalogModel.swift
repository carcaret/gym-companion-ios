import Application
import Domain
import Observation
import Presentation

/// El catálogo de ejercicios, dentro de Progreso: todos los ejercicios por grupo (entrenados o no),
/// con buscador, y el editor de nombre, grupo principal y secundarios.
@MainActor
@Observable
public final class CatalogModel {
    public struct Section: Hashable, Sendable, Identifiable {
        public var id: String { title }
        public let title: String
        public let rows: [Row]
    }

    public struct Row: Hashable, Sendable, Identifiable {
        public var id: ExerciseID { exerciseID }
        public let exerciseID: ExerciseID
        public let name: String
        /// Los secundarios, con su ortografía.
        public let secondaries: [String]
    }

    /// El editor de un ejercicio.
    public struct Editor: Hashable, Sendable {
        public let exerciseID: ExerciseID
        public var name: String
        public var group: MuscleGroup?
        public var secondaries: [MuscleGroup]
    }

    /// Un chip de secundario: el del grupo principal está desactivado (contaría dos veces).
    public struct SecondaryChip: Hashable, Sendable, Identifiable {
        public var id: MuscleGroup { group }
        public let group: MuscleGroup
        public let title: String
        public let isOn: Bool
        public let isEnabled: Bool
    }

    public var query = ""
    public var editor: Editor?
    /// El editor tal como se abrió: con qué se comparan los cambios.
    private var editorOriginal: Editor?
    /// La ✕ con cambios: «Descartar cambios» o seguir.
    public var isDiscardPromptPresented = false

    private let app: AppModel

    public init(app: AppModel) {
        self.app = app
    }

    private var data: TrainingData { app.data ?? TrainingData() }

    // MARK: - Resumen

    private var total: Int { data.catalog.ids.count }

    /// Los que no tienen uno de los grupos que se pueden elegir.
    private var withoutGroup: Int { data.catalog.all.filter { $0.knownGroup == nil }.count }

    /// Debajo del título del catálogo: «4 en total · 1 sin grupo» (antes, la tarjeta de Progreso).
    public var summary: String { CatalogText.summary(total: total, withoutGroup: withoutGroup) }

    // MARK: - Lista

    public var sections: [Section] {
        data.catalog.groups(matching: query).map { group in
            Section(title: GroupText.name(group.group), rows: group.exercises.map { exercise in
                Row(exerciseID: exercise.id, name: exercise.name, secondaries: (exercise.secondaryGroups ?? []).map(GroupText.name))
            })
        }
    }

    /// Volver a Progreso: la búsqueda se olvida.
    public func leave() {
        query = ""
        editor = nil
    }

    // MARK: - Editor

    public func edit(_ exercise: ExerciseID) {
        guard let current = data.catalog[exercise] else { return }
        editor = Editor(exerciseID: exercise, name: data.catalog.name(of: exercise), group: current.knownGroup,
                        secondaries: SecondaryGroups.resolve(current, id: exercise))
        editorOriginal = editor
    }

    /// Algo cambiado en el editor (el orden de los secundarios no cuenta).
    public var hasChanges: Bool {
        guard let editor, let editorOriginal else { return false }
        return editor.name != editorOriginal.name || editor.group != editorOriginal.group
            || Set(editor.secondaries) != Set(editorOriginal.secondaries)
    }

    /// La ✕: sin cambios, cierra; con cambios, pregunta antes de tirarlos (como las demás hojas).
    public func requestClose() {
        guard hasChanges else { return closeEditor() }
        isDiscardPromptPresented = true
    }

    /// «Descartar cambios». No depende del diálogo, que SwiftUI cierra antes de la acción.
    public func discardChanges() {
        closeEditor()
    }

    public func keepEditing() {
        isDiscardPromptPresented = false
    }

    /// Elegir el grupo principal apaga ese grupo entre los secundarios.
    public func setGroup(_ group: MuscleGroup?) {
        editor?.group = group
        editor?.secondaries.removeAll { $0 == group }
    }

    public func toggleSecondary(_ group: MuscleGroup) {
        guard var editor, group != editor.group else { return }
        if editor.secondaries.contains(group) {
            editor.secondaries.removeAll { $0 == group }
        } else {
            editor.secondaries.append(group)
        }
        self.editor = editor
    }

    public var chips: [SecondaryChip] {
        guard let editor else { return [] }
        return MuscleGroup.all.map { group in
            SecondaryChip(group: group, title: GroupText.name(group), isOn: editor.secondaries.contains(group), isEnabled: group != editor.group)
        }
    }

    /// La ✓, apagada sin cambios o con el nombre vacío.
    public var canSave: Bool { hasChanges && !(editor?.name.trimmingWhitespace().isEmpty ?? true) }

    /// La ✓. Si no vale, el editor sigue abierto (la interfaz no deja llegar a eso).
    public func save() async {
        guard let editor, canSave else { return }
        var data = data
        let secondaries = MuscleGroup.all.filter(editor.secondaries.contains)
        do {
            try data.catalog.update(editor.exerciseID, name: editor.name, group: editor.group, secondaryGroups: secondaries)
        } catch {
            return
        }
        self.editor = nil
        await app.update(data)
    }

    /// Cierra el editor sin preguntar (la hoja ya se ha cerrado).
    public func closeEditor() {
        editor = nil
        editorOriginal = nil
        isDiscardPromptPresented = false
    }
}
