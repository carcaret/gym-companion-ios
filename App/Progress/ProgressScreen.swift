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
        // Sin nada que comparar: qué hacer, en vez de «Nada estancado · 0 progresando» y barras a
        // cero (repaso de la HIG, 2026-10-28).
        .overlay {
            if !model.hasProgress {
                ContentUnavailableView(ProgressText.emptyTitle, systemImage: "chart.line.uptrend.xyaxis",
                                       description: Text(ProgressText.emptyMessage))
                    .background(Theme.background)
            }
        }
        .navigationTitle(ProgressText.title)
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
            // Los márgenes de cada fila van dentro de su botón: se toca la fila entera.
            DisclosureHeader(isExpanded: model.isExpanded, identifier: "stats-exercises",
                             padding: EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16), minHeight: 48,
                             toggle: model.toggleExpanded) {
                Text(model.exercisesSubtitle).scaledFont(13).foregroundStyle(Theme.textSecondary)
            }
            ForEach(model.visibleRows) { row in
                ListSeparator(inset: 16)
                ExerciseProgressRow(row: row, toggle: { model.toggleRow(row.exerciseID) }, openCharts: { model.openCharts(row.exerciseID) })
            }
        } header: {
            header(ProgressText.exercisesTitle)
        }
    }

    private var groups: some View {
        ListSection {
            ForEach(Array(model.groups.enumerated()), id: \.element.id) { index, group in
                if index > 0 { ListSeparator(inset: 16) }
                GroupBarRow(group: group, scale: model.scale, band: model.referenceBand) { model.toggleGroup(group.name) }
            }
        } header: {
            header(ProgressText.groupsTitle)
        } footer: {
            HStack(spacing: 14) {
                legend(ProgressText.direct, Theme.accent)
                legend(ProgressText.indirect, Theme.indirect)
                legend(ProgressText.referenceBand(model.referenceBand), Theme.referenceBand, border: Theme.referenceBandBorder)
            }
            .scaledFont(11)
            .foregroundStyle(Theme.textSecondary)
        }
    }

    /// La cabecera de una sección: el título y, a la derecha, la ventana de semanas.
    private func header(_ title: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            // VoiceOver salta de una sección a otra con el rotor de encabezados.
            Text(title).scaledFont(17, .semibold).foregroundStyle(Theme.textSecondary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            // Más pequeña que el título: es un dato de la sección, no otro título.
            Text(ProgressText.window(weeks: ProgressModel.weeks)).scaledFont(13).foregroundStyle(Theme.textSecondary)
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
