import Domain
import Presentation
import SwiftUI
import ViewModels

/// La pestaña Historial: la lista de sesiones y el detalle de una. Solo pinta `HistoryModel`.
struct HistoryScreen: View {
    @Bindable var model: HistoryModel

    var body: some View {
        Group {
            if model.selectedDate != nil { detail } else { list }
        }
        .navigationTitle(model.selectedDate == nil ? HistoryText.title : model.detailTitle)
        .navigationBarTitleDisplayMode(model.selectedDate == nil ? .large : .inline)
        .onAppear { model.appear() }
        .confirmationDialog(model.deletePrompt?.title ?? "", isPresented: Binding(
            get: { model.deletePrompt != nil }, set: { if !$0 { model.cancelDelete() } }
        ), titleVisibility: .visible) {
            Button(HistoryText.deleteConfirm, role: .destructive) { Task { await model.confirmDelete() } }
            Button(HistoryText.cancel, role: .cancel) { model.cancelDelete() }
        } message: {
            Text(model.deletePrompt?.message ?? "")
        }
    }

    @ViewBuilder
    private var list: some View {
        if model.rows.isEmpty {
            ContentUnavailableView(HistoryText.empty, systemImage: "list.clipboard")
        } else {
            List(model.rows) { row in
                Button { model.open(row.date) } label: { HistoryRowView(row: row) }
                    .foregroundStyle(.primary)
                    .listRowBackground(row.isIncomplete ? Color.blue.opacity(0.08) : nil)
                    .swipeActions {
                        Button(HistoryText.deleteConfirm, systemImage: "trash", role: .destructive) { model.requestDelete(row.date) }
                    }
                    .accessibilityIdentifier("history-\(row.date.iso)")
            }
        }
    }

    private var detail: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if model.isIncomplete {
                    Label(HistoryText.incomplete, systemImage: "clock")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(Array(model.cards.enumerated()), id: \.offset) { index, card in
                    ExerciseCardView(card: card, toggle: { model.toggleCard(index) }, actions: actions(index), save: {
                        Task { await model.save(index) }
                    })
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            BottomActions {
                Button { model.back() } label: { Label(HistoryText.back, systemImage: "chevron.left") }
                    .buttonStyle(.bordered)
                    .fixedSize()
            } primary: {
                if model.isIncomplete {
                    Button { Task { await model.completeWorkout() } } label: { Text(HistoryText.completeWorkout).frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent)
                } else {
                    Spacer()
                }
            }
        }
    }

    private func actions(_ index: Int) -> ExerciseCardView.CardActions {
        ExerciseCardView.CardActions(
            adjust: { parameter, direction in model.adjust(parameter, direction: direction, at: index) },
            set: { parameter, text in model.set(parameter, text: text, at: index) },
            focusSeries: { series in model.focusSeries(series, at: index) },
            chooseRep: { value, series in model.chooseRep(value, series: series, at: index) },
            swap: nil, toggleSkip: nil, remove: nil
        )
    }
}

private struct HistoryRowView: View {
    let row: HistoryModel.Row

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(row.day).font(.title2.weight(.bold))
                Text(row.month).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            }
            .frame(width: 44)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(row.routine).font(.subheadline.weight(.semibold))
                    Text(row.relative).font(.caption).foregroundStyle(.secondary)
                    if row.isIncomplete { Image(systemName: "pause.circle.fill").foregroundStyle(.blue).accessibilityLabel(HistoryText.incomplete) }
                }
                Text(row.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}
