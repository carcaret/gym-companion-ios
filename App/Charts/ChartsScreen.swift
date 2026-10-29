import Charts
import Domain
import Presentation
import SwiftUI
import ViewModels

/// La pestaña Gráficas, y las gráficas de un ejercicio empujadas desde Progreso: el rango (atajos
/// de meses, como en la app Salud, y debajo las fechas a mano), el ejercicio elegido (se elige en su propia pantalla, como los selectores de Ajustes de iOS) y
/// las gráficas de 1RM estimado y de peso. Solo pinta `ChartsModel`.
struct ChartsScreen: View {
    @Bindable var model: ChartsModel

    var body: some View {
        List {
            Section {
                // Sin atajo (fechas a mano), ninguno marcado.
                Picker(ChartsText.range, selection: Binding(get: { model.preset }, set: { if let preset = $0 { model.choose(preset: preset) } })) {
                    ForEach(ChartsModel.RangePreset.allCases, id: \.self) { preset in
                        Text(ChartsText.presetLabel(months: preset.months))
                            .accessibilityLabel(ChartsText.presetAccessibilityLabel(months: preset.months))
                            .tag(Optional(preset))
                    }
                }
                .pickerStyle(.segmented)
                DatePicker(ChartsText.from, selection: Binding(
                    get: { model.from.date }, set: { model.setRange(from: LocalDate($0), to: model.to) }
                ), displayedComponents: .date)
                DatePicker(ChartsText.to, selection: Binding(
                    get: { model.to.date }, set: { model.setRange(from: model.from, to: LocalDate($0)) }
                ), displayedComponents: .date)
                NavigationLink(value: ChartsExercisePickerRoute()) {
                    // «Elegir», apagado como el texto de ejemplo de un campo: sin él parecía un
                    // ejercicio elegido (la lista entera va en el color del texto).
                    LabeledContent(ChartsText.exercise) {
                        Text(model.selectedName ?? ChartsText.chooseExercise)
                            .foregroundStyle(model.selectedName == nil ? Theme.textSecondary : Theme.text)
                    }
                }
                .accessibilityIdentifier(AccessibilityID.chartExercise)
            }
            .listRowBackground(Theme.surface)
            if model.charts.isEmpty {
                Section { Text(ChartsText.empty).foregroundStyle(Theme.textSecondary) }
                    .listRowBackground(Theme.surface)
            } else {
                ForEach(model.charts, id: \.label) { chart in
                    Section {
                        ProgressChart(chart: chart)
                    } header: {
                        Text(chart.axisTitle).scaledFont(16, .bold).foregroundStyle(Theme.text).textCase(nil)
                    }
                    .listRowBackground(Theme.surface)
                }
            }
        }
        .navigationTitle(ChartsText.title)
        .foregroundStyle(Theme.text)
        .navigationDestination(for: ChartsExercisePickerRoute.self) { _ in ChartsExercisePicker(model: model).syncToolbar() }
    }
}
