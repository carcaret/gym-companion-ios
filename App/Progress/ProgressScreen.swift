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
    }

    private var exercises: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button { model.toggleExpanded() } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(StatsText.exercisesTitle).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
                            Spacer()
                            Text(StatsText.window(weeks: ProgressModel.weeks)).sectionLabelStyle()
                        }
                        Text(model.exercisesSubtitle).font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .rotationEffect(.degrees(model.isExpanded ? 180 : 0))
                        .foregroundStyle(Theme.textMuted)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("stats-exercises")
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
                Text(StatsText.groupsTitle).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
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
            .font(.system(size: 11))
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
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggle) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(row.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(noTrack ? Theme.textSecondary : Theme.text)
                            Spacer()
                            if let weight = row.weight {
                                Text(weight).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.accentLight)
                            }
                        }
                        Text(row.phrase).font(.system(size: 12)).foregroundStyle(noTrack ? Theme.textMuted : Theme.textSecondary)
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .rotationEffect(.degrees(row.isOpen ? 180 : 0))
                        .foregroundStyle(Theme.textMuted)
                }
                .padding(.vertical, 12)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            if row.isOpen {
                VStack(alignment: .leading, spacing: 6) {
                    Text(StatsText.recentSessions).sectionLabelStyle()
                    Text(row.recentReps.joined(separator: "  ·  "))
                        .font(.system(size: 13).monospacedDigit())
                        .foregroundStyle(noTrack ? Theme.textSecondary : Theme.text)
                    if row.canOpenCharts {
                        Button(StatsText.openCharts, action: openCharts).buttonStyle(.pill(.subtle)).padding(.top, 6)
                    }
                }
                .padding(.bottom, 14)
            }
        }
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

/// Barra de series de un grupo (`.stats-group-bar-row`), en la escala común: la franja de
/// referencia detrás y sus límites encima, para que una barra larga no los tape.
private struct GroupBarRow: View {
    let group: ProgressModel.GroupRow
    let scale: Double
    let band: ClosedRange<Int>
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: toggle) {
                HStack(spacing: 10) {
                    Text(group.name).font(.system(size: 12)).foregroundStyle(Theme.textSecondary).frame(width: 62, alignment: .leading)
                    GeometryReader { proxy in
                        let width = proxy.size.width
                        let x = { (value: Double) in width * CGFloat(min(value / scale, 1)) }
                        ZStack(alignment: .leading) {
                            Theme.input
                            Rectangle().fill(Color.white.opacity(0.10))
                                .frame(width: x(Double(band.upperBound)) - x(Double(band.lowerBound)))
                                .offset(x: x(Double(band.lowerBound)))
                            HStack(spacing: 0) {
                                Rectangle().fill(Theme.accent).frame(width: x(Double(group.sets)))
                                Rectangle().fill(Theme.accent.opacity(0.32)).frame(width: x(group.indirectSets))
                            }
                            .clipShape(.rect(cornerRadius: 3))
                            ForEach([band.lowerBound, band.upperBound], id: \.self) { limit in
                                Rectangle().fill(Color.white.opacity(0.45)).frame(width: 1).offset(x: x(Double(limit)))
                            }
                        }
                        .clipShape(.rect(cornerRadius: 3))
                    }
                    .frame(height: 14)
                    Text("\(group.total)").font(.system(size: 13, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.text)
                        .frame(width: 26, alignment: .trailing)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            if group.isOpen {
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
                .padding(.top, 8)
            }
        }
    }

    private func detailRow(_ name: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Text(name).lineLimit(1)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(.system(size: 12))
        .foregroundStyle(Theme.textSecondary)
    }
}
