import Charts
import Presentation
import SwiftUI
import ViewModels

/// La tira "Últimas sesiones" de un ejercicio: seis columnas, la de hoy la última, en una gráfica
/// de barras de Swift Charts. Un toque en una barra enseña su detalle (el tooltip de la PWA) en un
/// bocadillo encima, como las gráficas de Salud, y apaga las demás; se va solo a los pocos
/// segundos, con otro toque en la misma o donde no hay sesión, y un toque en otra barra lo cambia
/// directamente (`TapSelection`; decisiones del usuario, 2026-10-27 y 2026-10-28). Con la selección
/// por arrastre de Swift Charts, dentro de una lista que se desplaza había que mantener el dedo.
struct HistoryStripView: View {
    let strip: HistoryStripContent
    @State private var selection = TapSelection<Int>()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let bubbleDuration: Duration = .seconds(3)

    /// El alto de las barras, en puntos: los 44 de la tira de la PWA menos la fecha. Las vacías,
    /// las saltadas y las muy bajas tienen 3.
    private static let plotHeight: CGFloat = 30
    private static let minimumHeight = Double(3 / plotHeight * 100)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(ProgressText.recentSessions).sectionLabelStyle()
                Spacer()
                if let delta = strip.deltaText {
                    Text(delta)
                        .scaledFont(11, .medium)
                        .foregroundStyle(strip.delta?.up == true ? Theme.greenSoft : Theme.redSoft)
                }
            }
            chart
        }
        .task(id: selection.selected) {
            guard let shown = selection.selected else { return }
            // Cancelado por otro toque, no cierra nada: el bocadillo que se ve ya es otro.
            guard (try? await Task.sleep(for: Self.bubbleDuration)) != nil else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { selection.expire(shown) }
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
                    .opacity(selection.selected == nil || selection.selected == index ? 1 : 0.4)
                    .cornerRadius(2)
                    .accessibilityLabel(tooltip(bar))
                    // En cada barra y no en la gráfica: en un contenedor pisaba lo de dentro.
                    .accessibilityIdentifier("strip-bar-\(index)")
                    .annotation(position: .top, spacing: 6, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        if selection.selected == index { bubble(bar) }
                    }
            }
        }
        .chartXScale(domain: keys)
        .chartYScale(domain: 0.0...100.0)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: keys) { value in
                AxisValueLabel {
                    if let key = value.as(String.self), let index = Int(key) {
                        Text(strip.bars[index].dateLabel).scaledFont(11).foregroundStyle(Theme.textSecondary)
                            .fixedSize()  // con letra grande, entera aunque roce la de al lado
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .chartPlotStyle { $0.frame(height: Self.plotHeight) }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let anchor = proxy.plotFrame {
                    let plot = geometry[anchor]
                    currentOutline(proxy, plot)
                        .allowsHitTesting(false)
                    // Un toque normal: no compite con el desplazamiento de la lista.
                    Rectangle().fill(.clear).contentShape(.rect)
                        .onTapGesture { location in tap(proxy.value(atX: location.x - plot.minX, as: String.self)) }
                        .accessibilityHidden(true)
                }
            }
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

    /// Solo las sesiones tienen detalle: un toque en una vacía o saltada cuenta como fuera.
    private func tap(_ key: String?) {
        let session = key.flatMap(Int.init).flatMap { index -> Int? in
            if case .session = strip.bars[index].kind { return index }
            return nil
        }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) { selection.tap(session) }
    }

    /// El detalle de una sesión: el peso y las reps destacados, y debajo el e1RM (las dos líneas del
    /// tooltip de la PWA, al revés), centradas. Sin la fecha: ya está debajo de la barra (decisión
    /// del usuario, 2026-10-27).
    @ViewBuilder
    private func bubble(_ bar: StripBar) -> some View {
        if case .session(_, _, _, let tooltip) = bar.kind, !tooltip.isEmpty {
            let lines = tooltip.split(separator: "\n").map(String.init)
            let main = lines.count > 1 ? lines[1] : lines[0]
            VStack(alignment: .center, spacing: 2) {
                Text(main).scaledFont(12, .semibold).foregroundStyle(Theme.text)
                if lines.count > 1 {
                    Text(lines[0]).scaledFont(11).foregroundStyle(Theme.textSecondary)
                }
            }
            .monospacedDigit()
            .fixedSize()
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Theme.surface2, in: .rect(cornerRadius: 10))
            .shadow(color: .black.opacity(0.45), radius: 9, y: 4)
            .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
        }
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
