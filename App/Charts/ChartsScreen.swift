import Charts
import Domain
import Presentation
import SwiftUI
import ViewModels

/// La pestaña Gráficas: rango de fechas, buscador de ejercicios y las gráficas de 1RM estimado y
/// de peso del elegido. Solo pinta `ChartsModel`.
struct ChartsScreen: View {
    @Bindable var model: ChartsModel
    @FocusState private var searching: Bool

    var body: some View {
        List {
            Section {
                DatePicker(ChartsText.from, selection: Binding(
                    get: { model.from.date }, set: { model.setRange(from: LocalDate($0), to: model.to) }
                ), displayedComponents: .date)
                DatePicker(ChartsText.to, selection: Binding(
                    get: { model.to.date }, set: { model.setRange(from: model.from, to: LocalDate($0)) }
                ), displayedComponents: .date)
            }
            .listRowBackground(Theme.surface)
            Section {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(ChartsText.searchPlaceholder, text: $model.query)
                        .focused($searching)
                        .accessibilityIdentifier("chart-search")
                    if model.showsClear {
                        Button { model.clear(); searching = true } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                    }
                }
                if searching || model.selected == nil {
                    if model.hasNoResults {
                        Text(ChartsText.noResults).foregroundStyle(.secondary)
                    } else {
                        ForEach(model.options.inRoutine) { option in row(option) }
                        if !model.options.inRoutine.isEmpty && !model.options.others.isEmpty { Divider() }
                        ForEach(model.options.others) { option in row(option) }
                    }
                }
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
                        Text(chart.axisTitle).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.text).textCase(nil)
                    }
                    .listRowBackground(Theme.surface)
                }
            }
        }
        .navigationTitle(ChartsText.title)
        .foregroundStyle(Theme.text)
        .toolbar {
            if model.canGoBack {
                ToolbarItem(placement: .topBarLeading) {
                    Button { model.goBack() } label: { Label(ChartsText.back, systemImage: "chevron.left") }
                }
            }
        }
        .onAppear { model.appear() }
    }

    private func row(_ option: ChartsModel.Option) -> some View {
        Button {
            model.select(option.exerciseID)
            searching = false
        } label: {
            HStack {
                Text(option.name)
                Spacer()
                if option.isSelected { Image(systemName: "checkmark").foregroundStyle(Theme.accentLight) }
            }
        }
        .foregroundStyle(option.isSelected ? Theme.accentLight : Theme.text)
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
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.text)
                            .padding(6)
                            .background(Theme.cardSolid, in: .rect(cornerRadius: 4))
                            .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.border, lineWidth: 0.5) }
                    }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartYScale(domain: chart.valueRange)
        .chartXScale(range: .plotDimension(padding: 16))  // que la primera y la última fecha no se corten
        .frame(height: 200)
        .accessibilityLabel(chart.axisTitle)
    }

    private var nearest: ChartPoint? {
        guard let selectedDate else { return nil }
        return chart.points.min { abs($0.date.date.timeIntervalSince(selectedDate)) < abs($1.date.date.timeIntervalSince(selectedDate)) }
    }
}
