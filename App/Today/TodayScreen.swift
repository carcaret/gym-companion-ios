import Domain
import Presentation
import SwiftUI
import ViewModels

/// La pestaña Rutinas: selector, vista previa, entreno en curso y entreno terminado. Solo pinta
/// `TodayModel`.
struct TodayScreen: View {
    @Bindable var model: TodayModel

    var body: some View {
        Group {
            switch model.stage {
            case .selector: selector
            case .preview: preview
            case .active: ActiveWorkoutView(model: model)
            case .completed: completed
            }
        }
        .navigationTitle(model.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.appear() }
    }

    private var selector: some View {
        List {
            Section {
                ForEach(model.routineRows, id: \.id) { row in
                    Button { model.select(row.id) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.title).font(.headline)
                            Text(row.subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                            if let note = row.pendingNote {
                                Label(note, systemImage: "arrow.left.arrow.right").font(.caption).foregroundStyle(.orange)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("routine-\(row.id.rawValue)")
                }
            } header: {
                Text(TodayText.selectorPrompt)
            }
        }
    }

    private var preview: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(model.previewCards.enumerated()), id: \.offset) { index, card in
                    ExerciseCardView(card: card, toggle: { model.togglePreviewCard(index) })
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button { model.backToSelector() } label: {
                    Label(TodayText.back, systemImage: "chevron.left").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Button { Task { await model.start() } } label: {
                    Text(TodayText.start).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .layoutPriority(1)
                .accessibilityIdentifier("start-workout")
            }
            .controlSize(.large)
            .padding()
            .background(.bar)
        }
    }

    private var completed: some View {
        List {
            Section {
                Label(TodayText.completedStatus, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.headline)
            }
            Section {
                ForEach(Array(model.completedRows.enumerated()), id: \.offset) { _, row in
                    SummaryRowView(title: row.title, subtitle: row.subtitle, isSkipped: row.isSkipped)
                }
            }
            Section {
                Button { model.backFromCompleted() } label: {
                    Label(TodayText.backToRoutines, systemImage: "chevron.left").frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("back-to-routines")
            }
        }
    }
}

/// Una línea de un entreno terminado (también la usa el historial).
struct SummaryRowView: View {
    let title: String
    let subtitle: String
    let isSkipped: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.body.weight(.medium))
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
        .opacity(isSkipped ? 0.5 : 1)
        .listRowBackground(isSkipped ? Color.gray.opacity(0.15) : nil)
    }
}
