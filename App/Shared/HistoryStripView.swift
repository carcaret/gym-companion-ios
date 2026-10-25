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
                Text("Últimas sesiones").sectionLabelStyle()
                Spacer()
                if let delta = strip.deltaText {
                    Text(delta)
                        .font(.scaled(11, weight: .medium))
                        .foregroundStyle(strip.delta?.up == true ? Theme.greenSoft : Theme.redSoft)
                }
            }
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(strip.bars.enumerated()), id: \.offset) { index, bar in
                    column(bar, index: index)
                }
            }
            .frame(height: 44)
            if let selected, case .session(_, _, _, let tooltip) = strip.bars[selected].kind, !tooltip.isEmpty {
                Text(tooltip.replacingOccurrences(of: "\n", with: " · "))
                    .font(.scaled(11, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.cardSolid, in: .rect(cornerRadius: 4))
                    .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.border, lineWidth: 0.5) }
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
                        UnevenRoundedRectangle(topLeadingRadius: 2, topTrailingRadius: 2).fill(Theme.border.opacity(0.4)).frame(height: 3)
                    case .skipped:
                        UnevenRoundedRectangle(topLeadingRadius: 2, topTrailingRadius: 2).fill(Theme.red.opacity(0.45)).frame(height: 3)
                    case .session(let height, let color, let isCurrent, let tooltip):
                        UnevenRoundedRectangle(topLeadingRadius: 2, topTrailingRadius: 2)
                            .fill(Color(red: Double(color.r) / 255, green: Double(color.g) / 255, blue: Double(color.b) / 255))
                            .overlay { if isCurrent { UnevenRoundedRectangle(topLeadingRadius: 2, topTrailingRadius: 2).stroke(Theme.text.opacity(0.6), lineWidth: 1) } }
                            .frame(height: max(3, proxy.size.height * CGFloat(height) / 100))
                            .onTapGesture { selected = selected == index ? nil : index }
                            .accessibilityLabel(tooltip.replacingOccurrences(of: "\n", with: " · "))
                    }
                }
            }
            Text(bar.dateLabel).font(.scaled(9)).foregroundStyle(Theme.textSecondary).frame(height: 12)
        }
        .frame(maxWidth: .infinity)
    }
}
