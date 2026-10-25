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
        List {
            exercises
            groups
            if let footer { Section { footer } }
        }
        .navigationTitle(StatsText.title)
    }

    private var exercises: some View {
        Section {
            Button { model.toggleExpanded() } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(StatsText.exercisesTitle).font(.headline)
                            Text(StatsText.window(weeks: ProgressModel.weeks)).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(model.exercisesSubtitle).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down").rotationEffect(.degrees(model.isExpanded ? 180 : 0)).foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)
            .accessibilityIdentifier("stats-exercises")
            ForEach(model.visibleRows) { row in
                ExerciseProgressRow(row: row, toggle: { model.toggleRow(row.exerciseID) }, openCharts: { model.openCharts(row.exerciseID) })
            }
        }
    }

    private var groups: some View {
        Section {
            ForEach(model.groups) { group in
                GroupBarRow(group: group, scale: model.scale, band: model.referenceBand) { model.toggleGroup(group.name) }
            }
        } header: {
            HStack {
                Text(StatsText.groupsTitle)
                Spacer()
                Text(StatsText.window(weeks: ProgressModel.weeks))
            }
        } footer: {
            HStack(spacing: 12) {
                Label(StatsText.direct, systemImage: "circle.fill").foregroundStyle(.blue)
                Label(StatsText.indirect, systemImage: "circle.fill").foregroundStyle(.blue.opacity(0.4))
                Label(StatsText.referenceBand(model.referenceBand), systemImage: "rectangle.fill").foregroundStyle(.green.opacity(0.5))
            }
            .font(.caption2)
        }
    }
}

private struct ExerciseProgressRow: View {
    let row: ProgressModel.ExerciseRow
    let toggle: () -> Void
    let openCharts: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: toggle) {
                HStack(alignment: .top) {
                    Circle().fill(color).frame(width: 8, height: 8).padding(.top, 6)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(row.name).font(.body.weight(.medium))
                            if let weight = row.weight { Text(weight).font(.caption).foregroundStyle(.secondary) }
                        }
                        Text(row.phrase).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down").rotationEffect(.degrees(row.isOpen ? 180 : 0)).foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)
            if row.isOpen {
                Text(StatsText.recentSessions).font(.caption).foregroundStyle(.secondary)
                Text(row.recentReps.joined(separator: "  ·  ")).font(.subheadline.monospacedDigit())
                if row.canOpenCharts {
                    Button(StatsText.openCharts, action: openCharts).buttonStyle(.bordered).controlSize(.small)
                }
            }
        }
    }

    private var color: Color {
        switch row.status {
        case .stalled: .orange
        case .progressing: .green
        case .noTrack: .gray
        }
    }
}

/// Barra de series de un grupo, en la escala común, con la franja de referencia detrás.
private struct GroupBarRow: View {
    let group: ProgressModel.GroupRow
    let scale: Double
    let band: ClosedRange<Int>
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: toggle) {
                HStack {
                    Text(group.name).frame(width: 80, alignment: .leading)
                    GeometryReader { proxy in
                        let width = proxy.size.width
                        ZStack(alignment: .leading) {
                            Rectangle().fill(.green.opacity(0.2))
                                .frame(width: width * CGFloat(Double(band.upperBound - band.lowerBound) / scale))
                                .offset(x: width * CGFloat(Double(band.lowerBound) / scale))
                            HStack(spacing: 0) {
                                Rectangle().fill(.blue).frame(width: width * CGFloat(Double(group.sets) / scale))
                                Rectangle().fill(.blue.opacity(0.4)).frame(width: width * CGFloat(group.indirectSets / scale))
                            }
                        }
                    }
                    .frame(height: 14)
                    Text("\(group.total)").font(.subheadline.monospacedDigit()).frame(width: 36, alignment: .trailing)
                }
            }
            .foregroundStyle(.primary)
            if group.isOpen {
                HStack { Text(StatsText.setsHeader); Text(StatsText.sessionsHeader) }.font(.caption2).foregroundStyle(.secondary)
                ForEach(Array(group.exercises.enumerated()), id: \.offset) { _, exercise in
                    HStack { Text(exercise.name); Spacer(); Text(exercise.value).monospacedDigit() }.font(.caption)
                }
                if !group.indirect.isEmpty {
                    Text(StatsText.indirect).font(.caption2).foregroundStyle(.secondary)
                    ForEach(Array(group.indirect.enumerated()), id: \.offset) { _, exercise in
                        HStack { Text(exercise.name); Spacer(); Text(exercise.value).monospacedDigit() }.font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
