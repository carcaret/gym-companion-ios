import Charts
import Domain
import Presentation
import SwiftUI
import ViewModels

/// La pestaña Progreso: la sección de ejercicios (estancados primero) y la de grupos musculares
/// (el catálogo, en la barra), con el aspecto de las secciones de lista de iOS 26 (decisión del usuario,
/// 2026-10-27). Un `VStack` y no una `List`: no necesita sus gestos, y en una `List` las filas que
/// se abren no animan bien (la cabecera pasaba por encima del contenido). Solo pinta `ProgressModel`.
struct ProgressScreen: View {
    let model: ProgressModel

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                exercises
                groups
            }
            .padding(16)
        }
        .navigationTitle(StatsText.title)
        // Las gráficas del ejercicio entran empujadas: se vuelve con la flecha de iOS o deslizando.
        .navigationDestination(isPresented: Binding(get: { model.charts != nil }, set: { if !$0 { model.closeCharts() } })) {
            if let charts = model.charts {
                ChartsScreen(model: charts).screenBackground().syncToolbar()
            }
        }
    }

    /// Plegada enseña solo los estancados (`visibleRows`); desplegada, todos. La primera fila, con
    /// el resumen, es la que pliega y despliega.
    private var exercises: some View {
        ListSection {
            DisclosureHeader(isExpanded: model.isExpanded, identifier: "stats-exercises", toggle: model.toggleExpanded) {
                Text(model.exercisesSubtitle).scaledFont(13).foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            ForEach(model.visibleRows) { row in
                ListSeparator(inset: 16)
                ExerciseProgressRow(row: row, toggle: { model.toggleRow(row.exerciseID) }, openCharts: { model.openCharts(row.exerciseID) })
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
        } header: {
            header(StatsText.exercisesTitle)
        }
    }

    private var groups: some View {
        ListSection {
            ForEach(Array(model.groups.enumerated()), id: \.element.id) { index, group in
                if index > 0 { ListSeparator(inset: 16) }
                GroupBarRow(group: group, scale: model.scale, band: model.referenceBand) { model.toggleGroup(group.name) }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
            }
        } header: {
            header(StatsText.groupsTitle)
        } footer: {
            HStack(spacing: 14) {
                legend(StatsText.direct, Theme.accent)
                legend(StatsText.indirect, Theme.accent.opacity(0.32))
                legend(StatsText.referenceBand(model.referenceBand), Color.white.opacity(0.07), border: Color.white.opacity(0.14))
            }
            .scaledFont(11)
            .foregroundStyle(Theme.textSecondary)
        }
    }

    /// La cabecera de una sección: el título y, a la derecha, la ventana de semanas.
    private func header(_ title: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).scaledFont(17, .semibold).foregroundStyle(Theme.textSecondary)
            Spacer()
            // Más pequeña que el título: es un dato de la sección, no otro título.
            Text(StatsText.window(weeks: ProgressModel.weeks)).scaledFont(13).foregroundStyle(Theme.textSecondary)
        }
    }

    private func legend(_ text: String, _ color: Color, border: Color = .clear) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
                .overlay { RoundedRectangle(cornerRadius: 2).strokeBorder(border) }
            Text(text)
        }
    }
}

/// Una sección con el aspecto de las de lista de iOS 26, fuera de una `List`: la cabecera encima,
/// las filas en un bloque redondeado y el pie debajo.
private struct ListSection<Content: View, Header: View, Footer: View>: View {
    @ViewBuilder let content: Content
    @ViewBuilder let header: Header
    @ViewBuilder let footer: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header.padding(.horizontal, 16)
            VStack(alignment: .leading, spacing: 0) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface, in: .rect(cornerRadius: Theme.radius))
            footer.padding(.horizontal, 16)
        }
    }
}

extension ListSection where Header == EmptyView, Footer == EmptyView {
    init(@ViewBuilder content: () -> Content) {
        self.init(content: content, header: { EmptyView() }, footer: { EmptyView() })
    }
}

extension ListSection where Footer == EmptyView {
    init(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> Header) {
        self.init(content: content, header: header, footer: { EmptyView() })
    }
}

/// La línea fina entre dos filas de una sección, con su sangría a la izquierda, como en iOS.
private struct ListSeparator: View {
    let inset: CGFloat

    var body: some View {
        Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.5).padding(.leading, inset)
    }
}

/// Un ejercicio (`.stats-row`), una fila de la lista: a la izquierda, el icono de su estado (como
/// los de Ajustes): azul y flecha si progresa, dorado e igual si está estancado, gris sin recorrido.
/// Al abrirla, sus últimas sesiones y «Ver en Gráficas».
private struct ExerciseProgressRow: View {
    let row: ProgressModel.ExerciseRow
    let toggle: () -> Void
    let openCharts: () -> Void
    @ScaledMetric(relativeTo: .subheadline) private var iconSide: CGFloat = 28

    var body: some View {
        CardDisclosure(isExpanded: row.isOpen, chevronSize: 12, identifier: "stats-row-\(row.exerciseID.rawValue)", toggle: toggle) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .scaledFont(13, .bold)
                    .foregroundStyle(noTrack ? Theme.text : Theme.background)
                    .frame(width: iconSide, height: iconSide)
                    .background(color, in: .rect(cornerRadius: 7))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.name).scaledFont(15, .medium).foregroundStyle(noTrack ? Theme.textSecondary : Theme.text)
                        Spacer()
                        if let weight = row.weight {
                            Text(weight).scaledFont(14, .semibold).foregroundStyle(Theme.accentLight)
                        }
                    }
                    Text(row.phrase).scaledFont(12).foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.vertical, 4)
        } content: {
            VStack(alignment: .leading, spacing: 6) {
                Text(StatsText.recentSessions).sectionLabelStyle()
                Text(row.recentReps.joined(separator: "  ·  "))
                    .scaledFont(13).monospacedDigit()
                    .foregroundStyle(noTrack ? Theme.textSecondary : Theme.text)
                if row.canOpenCharts {
                    Button(StatsText.openCharts, action: openCharts)
                        .scaledFont(15)
                        .foregroundStyle(Theme.accentLight)
                        .buttonStyle(.plain)
                        .frame(minHeight: 44)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, iconSide + 12)
            .padding(.top, 8)
        }
    }

    private var noTrack: Bool { row.status == .noTrack }

    private var symbol: String {
        switch row.status {
        case .progressing: "arrow.up.right"
        case .stalled: "equal"
        case .noTrack: "minus"
        }
    }

    private var color: Color {
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
        CardDisclosure(isExpanded: group.isOpen, chevronSize: 11, toggle: toggle) {
            HStack(spacing: 10) {
                Text(group.name).scaledFont(12).foregroundStyle(Theme.textSecondary).frame(width: nameWidth, alignment: .leading)
                GroupBar(group: group, scale: scale, band: band)
                    .frame(height: 14)
                Text("\(group.total)").scaledFont(13, .semibold).monospacedDigit().foregroundStyle(Theme.text)
                    .frame(width: totalWidth, alignment: .trailing)
            }
        } content: {
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
