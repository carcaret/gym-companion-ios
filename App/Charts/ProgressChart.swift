import Charts
import Domain
import Presentation
import SwiftUI
import ViewModels

/// Una gráfica de línea con sus puntos. Un toque enseña el valor del punto más cercano en un
/// bocadillo, que se va solo a los 3 s o con otro toque en el mismo, y un toque en otro punto lo
/// cambia directamente, como «Últimas sesiones» (`TapSelection`; repaso de la HIG, 2026-10-28):
/// con la selección por arrastre, dentro de una lista que se desplaza había que mantener el dedo.
struct ProgressChart: View {
    let chart: ChartsModel.Chart
    @State private var selection = TapSelection<LocalDate>()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Chart {
            ForEach(chart.points, id: \.date) { point in
                LineMark(x: .value(ChartsText.dateAxis, point.date.date), y: .value(chart.label, point.value))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Theme.accent)
                AreaMark(x: .value(ChartsText.dateAxis, point.date.date), yStart: .value(chart.label, chart.valueRange.lowerBound),
                         yEnd: .value(chart.label, point.value))
                    .interpolationMethod(.monotone)  // la misma curva que la línea
                    .foregroundStyle(Theme.accent.opacity(0.08))
                PointMark(x: .value(ChartsText.dateAxis, point.date.date), y: .value(chart.label, point.value))
                    .foregroundStyle(Theme.accent)
                    .symbolSize(point.isCarriedForward ? 15 : 30)
                    .opacity(point.isCarriedForward ? 0.4 : 1)
            }
            if let selected = nearest {
                RuleMark(x: .value(ChartsText.dateAxis, selected.date.date))
                    .foregroundStyle(Theme.textSecondary)
                    // Dentro de la gráfica: fuera de ella, la fila de la lista cortaba la mitad de
                    // arriba. Con el aspecto del bocadillo de «Últimas sesiones».
                    .annotation(position: .top, spacing: 4, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        Text(ChartsText.pointLabel(chart.label, value: selected.value, carriedForward: selected.isCarriedForward))
                            .scaledFont(12, .semibold)
                            .foregroundStyle(Theme.text)
                            .chartBubble()
                    }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let anchor = proxy.plotFrame {
                    let plot = geometry[anchor]
                    // Un toque normal: no compite con el desplazamiento de la lista.
                    Rectangle().fill(.clear).contentShape(.rect)
                        .onTapGesture { location in tap(proxy.value(atX: location.x - plot.minX, as: Date.self)) }
                        .accessibilityHidden(true)
                }
            }
        }
        .expiringBubble($selection)
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
        selection.selected.flatMap { date in chart.points.first { $0.date == date } }
    }

    private func point(nearestTo date: Date) -> ChartPoint? {
        chart.points.min { abs($0.date.date.timeIntervalSince(date)) < abs($1.date.date.timeIntervalSince(date)) }
    }

    private func tap(_ date: Date?) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
            selection.tap(date.flatMap(point(nearestTo:))?.date)
        }
    }
}
