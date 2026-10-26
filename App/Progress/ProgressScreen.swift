import Charts
import Domain
import Presentation
import SwiftUI
import ViewModels

/// La pestaña Progreso: la tarjeta de ejercicios (estancados primero) y la de grupos musculares.
/// Solo pinta `ProgressModel`.
struct ProgressScreen: View {
    let model: ProgressModel
    /// Lo que hay debajo (la entrada al catálogo, #13).
    var footer: AnyView?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                exercises
                groups
                if let footer { footer }
            }
            .padding(16)
        }
        .navigationTitle(StatsText.title)
        // Las gráficas del ejercicio entran empujadas: se vuelve con la flecha de iOS o deslizando.
        .navigationDestination(isPresented: Binding(get: { model.charts != nil }, set: { if !$0 { model.closeCharts() } })) {
            if let charts = model.charts {
                ChartsScreen(model: charts).screenBackground()
            }
        }
    }

    /// Plegada enseña solo los estancados (`visibleRows`); desplegada, todos.
    private var exercises: some View {
        VStack(alignment: .leading, spacing: 14) {
            DisclosureHeader(isExpanded: model.isExpanded, identifier: "stats-exercises", toggle: { withAnimation(.snappy) { model.toggleExpanded() } }) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(StatsText.exercisesTitle).scaledFont(15, .semibold).foregroundStyle(Theme.text)
                        Spacer()
                        Text(StatsText.window(weeks: ProgressModel.weeks)).sectionLabelStyle()
                    }
                    Text(model.exercisesSubtitle).scaledFont(12).foregroundStyle(Theme.textSecondary)
                }
            }
            VStack(spacing: 2) {
                ForEach(model.visibleRows) { row in
                    ExerciseProgressRow(row: row, toggle: { model.toggleRow(row.exerciseID) }, openCharts: { model.openCharts(row.exerciseID) })
                }
            }
        }
        .card()
    }

    private var groups: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(StatsText.groupsTitle).scaledFont(15, .semibold).foregroundStyle(Theme.text)
                Spacer()
                Text(StatsText.window(weeks: ProgressModel.weeks)).sectionLabelStyle()
            }
            .padding(.bottom, 2)
            ForEach(model.groups) { group in
                GroupBarRow(group: group, scale: model.scale, band: model.referenceBand) { model.toggleGroup(group.name) }
            }
            HStack(spacing: 14) {
                legend(StatsText.direct, Theme.accent)
                legend(StatsText.indirect, Theme.accent.opacity(0.32))
                legend(StatsText.referenceBand(model.referenceBand), Color.white.opacity(0.07), border: Color.white.opacity(0.14))
            }
            .scaledFont(11)
            .foregroundStyle(Theme.textMuted)
            .padding(.top, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) { Rectangle().fill(Theme.borderLight).frame(height: 1) }
            .padding(.top, 4)
        }
        .card()
    }

    private func legend(_ text: String, _ color: Color, border: Color = .clear) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
                .overlay { RoundedRectangle(cornerRadius: 2).strokeBorder(border) }
            Text(text)
        }
    }
}

/// Un ejercicio (`.stats-row`): el filete de la izquierda es el código de color (azul progresa,
/// dorado estancado, gris sin recorrido; el verde no, que en la tira significa quedarse corto).
private struct ExerciseProgressRow: View {
    let row: ProgressModel.ExerciseRow
    let toggle: () -> Void
    let openCharts: () -> Void

    var body: some View {
        DisclosureGroup(isExpanded: Binding(isOpen: row.isOpen, toggle: toggle)) {
            VStack(alignment: .leading, spacing: 6) {
                Text(StatsText.recentSessions).sectionLabelStyle()
                Text(row.recentReps.joined(separator: "  ·  "))
                    .scaledFont(13).monospacedDigit()
                    .foregroundStyle(noTrack ? Theme.textSecondary : Theme.text)
                if row.canOpenCharts {
                    Button(StatsText.openCharts, action: openCharts).buttonStyle(.pill(.subtle)).padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 14)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(row.name).scaledFont(14, .semibold).foregroundStyle(noTrack ? Theme.textSecondary : Theme.text)
                    Spacer()
                    if let weight = row.weight {
                        Text(weight).scaledFont(13, .semibold).foregroundStyle(Theme.accentLight)
                    }
                }
                Text(row.phrase).scaledFont(12).foregroundStyle(noTrack ? Theme.textMuted : Theme.textSecondary)
            }
            .padding(.vertical, 12)
        }
        .disclosureGroupStyle(.card(chevronSize: 12, identifier: "stats-row-\(row.exerciseID.rawValue)"))
        .padding(.leading, 10)
        .overlay(alignment: .leading) { Rectangle().fill(stripe).frame(width: 3) }
    }

    private var noTrack: Bool { row.status == .noTrack }

    private var stripe: Color {
        switch row.status {
        case .progressing: Theme.accent
        case .stalled: Theme.gold
        case .noTrack: Theme.borderStrong
        }
    }
}

/// Una fila de grupo (`.stats-group-bar-row`): el nombre, la barra y el total; al tocarla, sus
/// ejercicios.
private struct GroupBarRow: View {
    let group: ProgressModel.GroupRow
    let scale: Double
    let band: ClosedRange<Int>
    let toggle: () -> Void
    /// El nombre y el total, con su ancho fijo de la PWA, crecen con la letra (Dynamic Type).
    @ScaledMetric(relativeTo: .caption) private var nameWidth: CGFloat = 62
    @ScaledMetric(relativeTo: .footnote) private var totalWidth: CGFloat = 26

    var body: some View {
        DisclosureGroup(isExpanded: Binding(isOpen: group.isOpen, toggle: toggle)) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) { Spacer(); Text(StatsText.setsHeader); Text(StatsText.sessionsHeader) }.sectionLabelStyle()
                ForEach(Array(group.exercises.enumerated()), id: \.offset) { _, exercise in
                    detailRow(exercise.name, exercise.value)
                }
                if !group.indirect.isEmpty {
                    Text(StatsText.indirect).sectionLabelStyle().padding(.top, 8)
                    ForEach(Array(group.indirect.enumerated()), id: \.offset) { _, exercise in
                        detailRow(exercise.name, exercise.value).opacity(0.75)
                    }
                }
            }
            .padding(.leading, 72)
            .padding(.top, 12)
        } label: {
            HStack(spacing: 10) {
                Text(group.name).scaledFont(12).foregroundStyle(Theme.textSecondary).frame(width: nameWidth, alignment: .leading)
                GroupBar(group: group, scale: scale, band: band)
                    .frame(height: 14)
                Text("\(group.total)").scaledFont(13, .semibold).monospacedDigit().foregroundStyle(Theme.text)
                    .frame(width: totalWidth, alignment: .trailing)
            }
        }
        .disclosureGroupStyle(.card(chevronSize: 11))
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
private struct GroupBar: View {
    let group: ProgressModel.GroupRow
    let scale: Double
    let band: ClosedRange<Int>

    var body: some View {
        let direct = min(Double(group.sets), scale)
        let total = min(Double(group.sets) + group.indirectSets, scale)
        Chart {
            RectangleMark(xStart: .value("Series", Double(band.lowerBound)), xEnd: .value("Series", Double(band.upperBound)),
                          y: .value("Grupo", group.name), height: .ratio(1))
                .foregroundStyle(Color.white.opacity(0.10))
            // Las indirectas, con el extremo redondeado, debajo de las directas: la unión queda
            // recta y el extremo de la barra entera, redondo.
            if total > direct {
                BarMark(xStart: .value("Series", 0.0), xEnd: .value("Series", total), y: .value("Grupo", group.name), height: .ratio(1))
                    .foregroundStyle(Theme.accent.opacity(0.32))
                    .cornerRadius(3)
            }
            BarMark(xStart: .value("Series", 0.0), xEnd: .value("Series", direct), y: .value("Grupo", group.name), height: .ratio(1))
                .foregroundStyle(Theme.accent)
                .cornerRadius(total > direct ? 0 : 3)
            ForEach([band.lowerBound, band.upperBound], id: \.self) { limit in
                RuleMark(x: .value("Series", Double(limit)))
                    .foregroundStyle(Color.white.opacity(0.45))
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
