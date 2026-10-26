import Charts
import Presentation
import SwiftUI

/// La tira "Últimas sesiones" de un ejercicio: seis columnas, la de hoy la última, en una gráfica
/// de barras de Swift Charts. Tocar una barra o pasar el dedo por encima enseña su detalle (el
/// tooltip de la PWA), que se queda al soltar.
struct HistoryStripView: View {
    let strip: HistoryStripContent
    @State private var selected: Int?
    /// La columna bajo el dedo mientras toca (`chartXSelection`); al soltar, `nil`.
    @State private var touched: String?

    /// El alto de las barras, en puntos: los 44 de la tira de la PWA menos la fecha. Las vacías,
    /// las saltadas y las muy bajas tienen 3.
    private static let plotHeight: CGFloat = 30
    private static let minimumHeight = Double(3 / plotHeight * 100)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Últimas sesiones").sectionLabelStyle()
                Spacer()
                if let delta = strip.deltaText {
                    Text(delta)
                        .scaledFont(11, .medium)
                        .foregroundStyle(strip.delta?.up == true ? Theme.greenSoft : Theme.redSoft)
                }
            }
            chart
            if let selected, case .session(_, _, _, let tooltip) = strip.bars[selected].kind, !tooltip.isEmpty {
                Text(tooltip.replacingOccurrences(of: "\n", with: " · "))
                    .scaledFont(11, .medium)
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.cardSolid, in: .rect(cornerRadius: 4))
                    .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.border, lineWidth: 0.5) }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var keys: [String] { strip.bars.indices.map(Self.key) }

    private var chart: some View {
        Chart {
            ForEach(Array(strip.bars.enumerated()), id: \.offset) { index, bar in
                // 2 pt a cada lado: los 4 pt entre columnas de la PWA.
                BarMark(x: .value("Sesión", Self.key(index)), yStart: .value("Altura", 0.0), yEnd: .value("Altura", height(bar)),
                        width: .inset(2))
                    .foregroundStyle(color(bar))
                    .cornerRadius(2)
                    .accessibilityLabel(tooltip(bar))
            }
        }
        .chartXScale(domain: keys)
        .chartYScale(domain: 0.0...100.0)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: keys) { value in
                AxisValueLabel {
                    if let key = value.as(String.self), let index = Int(key) {
                        Text(strip.bars[index].dateLabel).scaledFont(9).foregroundStyle(Theme.textSecondary)
                            .fixedSize()  // con letra grande, entera aunque roce la de al lado
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .chartPlotStyle { $0.frame(height: Self.plotHeight) }
        .chartXSelection(value: $touched)
        .onChange(of: touched) { previous, key in touch(key, continuing: previous != nil) }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let anchor = proxy.plotFrame {
                    currentOutline(proxy, geometry[anchor])
                }
            }
            .allowsHitTesting(false)
        }
    }

    /// La barra de hoy, con el borde claro de la PWA encima.
    @ViewBuilder
    private func currentOutline(_ proxy: ChartProxy, _ plot: CGRect) -> some View {
        if let index = strip.bars.firstIndex(where: { if case .session(_, _, true, _) = $0.kind { true } else { false } }),
           let x = proxy.position(forX: Self.key(index)), let top = proxy.position(forY: height(strip.bars[index])) {
            UnevenRoundedRectangle(topLeadingRadius: 2, topTrailingRadius: 2)
                .stroke(Theme.text.opacity(0.6), lineWidth: 1)
                .frame(width: plot.width / CGFloat(strip.bars.count) - 4, height: plot.height - top)
                .position(x: plot.minX + x, y: plot.minY + (top + plot.height) / 2)
        }
    }

    /// Solo las sesiones tienen detalle. Al arrastrar, el de la que hay debajo; un toque nuevo en
    /// la que ya se ve lo cierra.
    private func touch(_ key: String?, continuing: Bool) {
        guard let key, let index = Int(key), case .session = strip.bars[index].kind else { return }
        selected = !continuing && selected == index ? nil : index
    }

    private static func key(_ index: Int) -> String { "\(index)" }

    private func height(_ bar: StripBar) -> Double {
        if case .session(let height, _, _, _) = bar.kind { return max(Self.minimumHeight, Double(height)) }
        return Self.minimumHeight
    }

    private func color(_ bar: StripBar) -> Color {
        switch bar.kind {
        case .empty: Theme.border.opacity(0.4)
        case .skipped: Theme.red.opacity(0.45)
        case .session(_, let color, _, _): Color(red: Double(color.r) / 255, green: Double(color.g) / 255, blue: Double(color.b) / 255)
        }
    }

    private func tooltip(_ bar: StripBar) -> String {
        if case .session(_, _, _, let tooltip) = bar.kind { return tooltip.replacingOccurrences(of: "\n", with: " · ") }
        return bar.dateLabel
    }
}
