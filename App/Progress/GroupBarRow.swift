import Charts
import Domain
import Presentation
import SwiftUI
import ViewModels

/// Una fila de grupo (`.stats-group-bar-row`): el nombre, la barra y el total; al tocarla, sus
/// ejercicios.
struct GroupBarRow: View {
    let group: ProgressModel.GroupRow
    let scale: Double
    let band: ClosedRange<Int>
    let toggle: () -> Void
    /// El nombre y el total, con su ancho fijo de la PWA, crecen con la letra (Dynamic Type).
    @ScaledMetric(relativeTo: .caption) private var nameWidth: CGFloat = 62
    @ScaledMetric(relativeTo: .footnote) private var totalWidth: CGFloat = 26

    var body: some View {
        CardDisclosure(isExpanded: group.isOpen, chevronSize: 11, identifier: AccessibilityID.statsGroup(group.name),
                       headerPadding: EdgeInsets(top: 13, leading: 16, bottom: 13, trailing: 16), toggle: toggle) {
            HStack(spacing: 10) {
                Text(group.name).scaledFont(12).foregroundStyle(Theme.textSecondary).frame(width: nameWidth, alignment: .leading)
                GroupBar(group: group, scale: scale, band: band)
                    .frame(height: 14)
                Text("\(group.total)").scaledFont(13, .semibold).monospacedDigit().foregroundStyle(Theme.text)
                    .frame(width: totalWidth, alignment: .trailing)
            }
        } content: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) { Spacer(); Text(ProgressText.setsHeader); Text(ProgressText.sessionsHeader) }.sectionLabelStyle()
                ForEach(Array(group.exercises.enumerated()), id: \.offset) { _, exercise in
                    detailRow(exercise.name, exercise.value)
                }
                if !group.indirect.isEmpty {
                    Text(ProgressText.indirect).sectionLabelStyle().padding(.top, 8)
                    ForEach(Array(group.indirect.enumerated()), id: \.offset) { _, exercise in
                        detailRow(exercise.name, exercise.value).opacity(0.75)
                    }
                }
            }
            // Alineado con la barra: el nombre, con su ancho que crece con la letra, y su hueco.
            .padding(.leading, nameWidth + 10)
            .padding(.horizontal, 16)
            .padding(.bottom, 13)
        }
    }

    private func detailRow(_ name: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Text(name).lineLimit(1)
            Spacer()
            Text(value).monospacedDigit()
        }
        .scaledFont(12)
        .foregroundStyle(Theme.textSecondary)
    }
}

/// La barra de series de un grupo, en Swift Charts y en la escala común: las directas y las
/// indirectas seguidas, la franja de referencia detrás y sus límites encima, para que una barra
/// larga no los tape.
struct GroupBar: View {
    let group: ProgressModel.GroupRow
    let scale: Double
    let band: ClosedRange<Int>

    var body: some View {
        let direct = min(Double(group.sets), scale)
        let total = min(Double(group.sets) + group.indirectSets, scale)
        Chart {
            RectangleMark(xStart: .value("Series", Double(band.lowerBound)), xEnd: .value("Series", Double(band.upperBound)),
                          y: .value("Grupo", group.name), height: .ratio(1))
                .foregroundStyle(Theme.referenceBandBar)
            // Las indirectas, con el extremo redondeado, debajo de las directas: la unión queda
            // recta y el extremo de la barra entera, redondo.
            if total > direct {
                BarMark(xStart: .value("Series", 0.0), xEnd: .value("Series", total), y: .value("Grupo", group.name), height: .ratio(1))
                    .foregroundStyle(Theme.indirect)
                    .cornerRadius(3)
            }
            BarMark(xStart: .value("Series", 0.0), xEnd: .value("Series", direct), y: .value("Grupo", group.name), height: .ratio(1))
                .foregroundStyle(Theme.accent)
                .cornerRadius(total > direct ? 0 : 3)
            ForEach([band.lowerBound, band.upperBound], id: \.self) { limit in
                RuleMark(x: .value("Series", Double(limit)))
                    .foregroundStyle(Theme.referenceLimit)
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
        }
        .chartXScale(domain: 0...scale, range: .plotDimension(padding: 0))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartPlotStyle { $0.background(Theme.input).clipShape(.rect(cornerRadius: 3)) }
        .accessibilityHidden(true)  // el total va al lado, en texto
    }
}
