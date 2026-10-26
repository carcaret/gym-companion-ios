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
                NavigationLink(value: ExercisePickerRoute()) {
                    LabeledContent(ChartsText.exercise, value: model.selectedName ?? ChartsText.chooseExercise)
                }
                .accessibilityIdentifier("chart-exercise")
            }
            .listRowBackground(Theme.surface)
            if model.charts.isEmpty {
                Section { Text(ChartsText.empty).foregroundStyle(Theme.textMuted) }
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
        .navigationDestination(for: ExercisePickerRoute.self) { _ in ExercisePicker(model: model) }
    }
}

/// La pantalla de elegir ejercicio, empujada con valor para que tocar otra vez la pestaña la cierre.
private struct ExercisePickerRoute: Hashable {}

/// Los ejercicios hechos en el rango, con buscador: los de alguna rutina y el resto. Elegir uno
/// vuelve a las gráficas.
private struct ExercisePicker: View {
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
        .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .always), prompt: ChartsText.searchPlaceholder)
        .navigationTitle(ChartsText.exercise)
        .navigationBarTitleDisplayMode(.inline)
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

/// Una gráfica de línea con sus puntos; tocar enseña el valor del punto más cercano.
private struct ProgressChart: View {
    let chart: ChartsModel.Chart
    @State private var selectedDate: Date?

    var body: some View {
        Chart {
            ForEach(chart.points, id: \.date) { point in
                LineMark(x: .value("Fecha", point.date.date), y: .value(chart.label, point.value))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Theme.accent)
                AreaMark(x: .value("Fecha", point.date.date), yStart: .value(chart.label, chart.valueRange.lowerBound),
                         yEnd: .value(chart.label, point.value))
                    .interpolationMethod(.monotone)  // la misma curva que la línea
                    .foregroundStyle(Theme.accent.opacity(0.08))
                PointMark(x: .value("Fecha", point.date.date), y: .value(chart.label, point.value))
                    .foregroundStyle(Theme.accent)
                    .symbolSize(point.isCarriedForward ? 15 : 30)
                    .opacity(point.isCarriedForward ? 0.4 : 1)
            }
            if let selected = nearest {
                RuleMark(x: .value("Fecha", selected.date.date))
                    .foregroundStyle(Theme.textMuted)
                    .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                        Text(ChartsText.pointLabel(chart.label, value: selected.value, carriedForward: selected.isCarriedForward))
                            .scaledFont(11, .medium)
                            .foregroundStyle(Theme.text)
                            .padding(6)
                            .background(Theme.cardSolid, in: .rect(cornerRadius: 4))
                            .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.border, lineWidth: 0.5) }
                    }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartYScale(domain: chart.valueRange)
        .chartXScale(range: .plotDimension(padding: 24))
        // Cada fecha centrada en su línea, con margen para que la última no se corte
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine()
                AxisValueLabel(anchor: .top)  // con el formato por defecto, que sigue el locale es_ES de la raíz
            }
        }
        .chartYAxis { AxisMarks(position: .leading) }      // a la izquierda, como en la PWA
        .frame(height: 200)
        .accessibilityLabel(chart.axisTitle)
    }

    private var nearest: ChartPoint? {
        guard let selectedDate else { return nil }
        return chart.points.min { abs($0.date.date.timeIntervalSince(selectedDate)) < abs($1.date.date.timeIntervalSince(selectedDate)) }
    }
}
