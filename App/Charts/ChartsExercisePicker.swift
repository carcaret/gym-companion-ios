import Domain
import Presentation
import SwiftUI
import ViewModels

/// La pantalla de elegir ejercicio, empujada con valor para que tocar otra vez la pestaña la cierre.
struct ChartsExercisePickerRoute: Hashable {}

/// Los ejercicios hechos en el rango, con buscador: los de alguna rutina y el resto. Elegir uno
/// vuelve a las gráficas.
struct ChartsExercisePicker: View {
    @Bindable var model: ChartsModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let options = model.options
        List {
            if !options.inRoutine.isEmpty {
                Section(ChartsText.inRoutine) { ForEach(options.inRoutine) { row($0) } }
                    .listRowBackground(Theme.surface)
            }
            if !options.others.isEmpty {
                Section(ChartsText.others) { ForEach(options.others) { row($0) } }
                    .listRowBackground(Theme.surface)
            }
        }
        .overlay {
            if model.hasNoResults {
                if model.query.isEmpty {
                    ContentUnavailableView(ChartsText.noResults, systemImage: "chart.bar")
                } else {
                    ContentUnavailableView.search(text: model.query)
                }
            }
        }
        .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .always), prompt: FormText.searchExercise)
        .navigationTitle(ChartsText.exercise)
        .screenBackground()
        .keyboardDismissal()
    }

    private func row(_ option: ChartsModel.Option) -> some View {
        Button {
            model.select(option.exerciseID)
            dismiss()
        } label: {
            HStack {
                Text(option.name).foregroundStyle(Theme.text)
                Spacer()
                if option.isSelected { Image(systemName: "checkmark").foregroundStyle(.tint) }
            }
        }
    }
}
