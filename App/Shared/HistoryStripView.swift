import Presentation
import SwiftUI

/// La tira "Últimas sesiones" de un ejercicio: seis columnas, la de hoy la última. Tocar una barra
/// enseña su detalle (el tooltip de la PWA).
struct HistoryStripView: View {
    let strip: HistoryStripContent
    @State private var selected: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Últimas sesiones").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let delta = strip.deltaText {
                    Text(delta)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(strip.delta?.up == true ? .green : .orange)
                }
            }
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(strip.bars.enumerated()), id: \.offset) { index, bar in
                    column(bar, index: index)
                }
            }
            .frame(height: 64)
            if let selected, case .session(_, _, _, let tooltip) = strip.bars[selected].kind, !tooltip.isEmpty {
                Text(tooltip.replacingOccurrences(of: "\n", with: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func column(_ bar: StripBar, index: Int) -> some View {
        VStack(spacing: 2) {
            GeometryReader { proxy in
                VStack {
                    Spacer(minLength: 0)
                    switch bar.kind {
                    case .empty:
                        Color.clear
                    case .skipped:
                        RoundedRectangle(cornerRadius: 3).fill(.gray.opacity(0.3)).frame(height: proxy.size.height * 0.06)
                    case .session(let height, let color, let isCurrent, let tooltip):
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(red: Double(color.r) / 255, green: Double(color.g) / 255, blue: Double(color.b) / 255))
                            .overlay { if isCurrent { RoundedRectangle(cornerRadius: 3).stroke(.primary.opacity(0.6), lineWidth: 1) } }
                            .frame(height: proxy.size.height * CGFloat(height) / 100)
                            .onTapGesture { selected = selected == index ? nil : index }
                            .accessibilityLabel(tooltip.replacingOccurrences(of: "\n", with: " · "))
                    }
                }
            }
            Text(bar.dateLabel).font(.system(size: 9)).foregroundStyle(.secondary).frame(height: 12)
        }
        .frame(maxWidth: .infinity)
    }
}
