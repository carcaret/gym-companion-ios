import Domain
import Presentation
import SwiftUI
import ViewModels

/// La pestaña Historial: la lista de sesiones y el detalle de una. Solo pinta `HistoryModel`.
struct HistoryScreen: View {
    @Bindable var model: HistoryModel

    var body: some View {
        list
            .navigationTitle(HistoryText.title)
            .navigationBarTitleDisplayMode(.large)
            .onAppear { model.appear() }
            // El detalle entra empujado, como en cualquier app de iOS: se vuelve también con el
            // botón de la barra o deslizando desde el borde.
            .navigationDestination(isPresented: Binding(
                get: { model.selectedDate != nil }, set: { if !$0 { model.back() } }
            )) {
                detail
                    .navigationTitle(model.detailTitle)
                    .navigationBarTitleDisplayMode(.inline)
                    .screenBackground()
            }
    }

    @ViewBuilder
    private var list: some View {
        if model.rows.isEmpty {
            ContentUnavailableView(HistoryText.empty, systemImage: "list.clipboard")
        } else {
            List(model.rows) { row in
                Button { model.open(row.date) } label: { HistoryRowView(row: row) }
                    .buttonStyle(.plain)
                    .cardRow()
                    .swipeActions {
                        Button(HistoryText.deleteConfirm, systemImage: "trash", role: .destructive) { model.requestDelete(row.date) }
                    }
                    // Colgado de su fila: en iOS 26 el diálogo sale como globo que apunta a su vista.
                    .confirmationDialog(model.deletePrompt?.title ?? "", isPresented: Binding(
                        get: { model.deletePrompt?.date == row.date }, set: { if !$0 { model.cancelDelete() } }
                    ), titleVisibility: .visible) {
                        Button(HistoryText.deleteConfirm, role: .destructive) { Task { await model.confirmDelete() } }
                        Button(HistoryText.cancel, role: .cancel) { model.cancelDelete() }
                    } message: {
                        Text(model.deletePrompt?.message ?? "")
                    }
                    .accessibilityIdentifier("history-\(row.date.iso)")
            }
            .listStyle(.plain)
            .screenBackground()
        }
    }

    private var detail: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if model.isIncomplete {
                    Label(HistoryText.incomplete, systemImage: "pause.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.accentLight)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Theme.accent.opacity(0.18), in: .capsule)
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
        .keyboardDismissal()
        .safeAreaInset(edge: .bottom) {
            if model.isIncomplete {
                BottomActions(primary: {
                    Button { Task { await model.completeWorkout() } } label: { Text(HistoryText.completeWorkout).frame(maxWidth: .infinity) }
                        .buttonStyle(.pill())
                })
            }
        }
    }

    private func actions(_ index: Int) -> ExerciseCardView.CardActions {
        ExerciseCardView.CardActions(
            adjust: { parameter, direction in model.adjust(parameter, direction: direction, at: index) },
            type: { parameter, text in model.type(parameter, text: text, at: index) },
            commit: { model.commitTyping() },
            focusSeries: { series in model.focusSeries(series, at: index) },
            chooseRep: { value, series in model.chooseRep(value, series: series, at: index) },
            swap: nil, toggleSkip: nil, remove: nil
        )
    }
}

/// Una sesión (`.historial-entry-btn`): la fecha en bloque, la etiqueta de la rutina con su color,
/// "hace…" y los ejercicios, con el filete del día. Sin terminar, con el tinte azul.
private struct HistoryRowView: View {
    let row: HistoryModel.Row

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(row.day).font(.system(size: 20, weight: .bold)).monospacedDigit().foregroundStyle(Theme.text)
                Text(row.month).font(.system(size: 9.5, weight: .semibold)).tracking(0.4).foregroundStyle(Theme.textMuted)
            }
            .frame(minWidth: 40)
            Rectangle().fill(Theme.border).frame(width: 1, height: 32)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    RoutineBadge(text: row.routine, color: Theme.color(row.tint) ?? Theme.textSecondary)
                    Text(row.relative).font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
                    if row.isIncomplete {
                        Image(systemName: "pause.fill").font(.system(size: 10)).foregroundStyle(Theme.accent).accessibilityLabel(HistoryText.incomplete)
                    }
                }
                Text(row.summary).font(.system(size: 12)).foregroundStyle(Theme.textSecondary).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .card(background: row.isIncomplete ? Theme.accent.opacity(0.07) : Theme.surface,
              border: row.isIncomplete ? Theme.accent.opacity(0.35) : Theme.border,
              stripe: Theme.color(row.tint))
        .contentShape(.rect)
    }
}

/// La etiqueta de una rutina (`.type-badge`): mayúsculas pequeñas en su color, sobre su color suave.
struct RoutineBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9.5, weight: .bold))
            .textCase(.uppercase)
            .tracking(0.4)
            .lineLimit(1)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.opacity(0.13), in: .rect(cornerRadius: Theme.radiusTag))
            .overlay { RoundedRectangle(cornerRadius: Theme.radiusTag).strokeBorder(color.opacity(0.27)) }
    }
}
