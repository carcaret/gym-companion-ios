import Domain
import Presentation
import SwiftUI
import ViewModels

/// La pestaña Historial: la lista de sesiones y el detalle de una. Solo pinta `HistoryModel`.
struct HistoryScreen: View {
    @Bindable var model: HistoryModel
    let sync: SyncModel
    /// Cada tirón que llega a sincronizar: su vibración (decisión del usuario, 2026-10-27).
    @State private var refreshes = 0

    var body: some View {
        list
            .navigationTitle(HistoryText.title)
            .navigationBarTitleDisplayMode(.large)
            // El detalle entra empujado, como en cualquier app de iOS: se vuelve también con el
            // botón de la barra o deslizando desde el borde.
            .navigationDestination(isPresented: Binding(
                get: { model.selectedDate != nil }, set: { if !$0 { model.back() } }
            )) {
                // Su propia vista, que lee el modelo: construida aquí, el cambio le llegaba sin la
                // animación y las tarjetas se abrían de golpe (vídeo del CI, 2026-10-27).
                SessionDetail(model: model)
                    .syncToolbar()
                    .navigationTitle(model.detailTitle)
                    .navigationSubtitle(model.detailSubtitle)
                    .navigationBarTitleDisplayMode(.inline)
                    .screenBackground()
            }
    }

    @ViewBuilder
    private var list: some View {
        if model.rows.isEmpty {
            ContentUnavailableView(HistoryText.empty, systemImage: "list.clipboard")
        } else {
            // Por meses, como Fotos o Fitness (2026-10-27).
            List(model.sections) { section in
                Section(section.title) {
                    ForEach(section.rows) { row in
                        Button { model.open(row.date) } label: { HistoryRowView(row: row) }
                            .buttonStyle(.card)
                            .cardRow()
                            .swipeActions {
                                // Sin `role: .destructive`: con ese rol la lista da la fila por borrada al
                                // tocarlo y la quita antes de que se confirme. El rojo, a mano.
                                Button(HistoryText.deleteConfirm, systemImage: "trash") { model.requestDelete(row.date) }
                                    .tint(Theme.red)
                            }
                            .accessibilityIdentifier("history-\(row.date.iso)")
                    }
                }
            }
            .listStyle(.plain)
            .screenBackground()
            // Tirar hacia abajo sincroniza con GitHub al momento y dice cómo ha quedado. Que la lista
            // se estire aunque quepa en la pantalla (con pocas sesiones); con esto se ha visto
            // funcionar en el simulador, sin esto no se ha probado.
            .scrollBounceBehavior(.always)
            .refreshable {
                refreshes += 1
                await sync.pullToRefresh()
            }
            // Un golpe suave al soltar pasado el umbral, como al actualizar en las apps de Apple.
            .sensoryFeedback(.impact(weight: .light), trigger: refreshes)
            // Alerta y no confirmationDialog: el botón de deslizar desaparece al tocarlo y el globo
            // no tendría de qué salir. `presenting` le pasa el aviso a la acción, porque SwiftUI
            // cierra la alerta (y la descarta) antes de ejecutarla.
            .alert(model.deletePrompt?.title ?? "", isPresented: Binding(
                get: { model.deletePrompt != nil }, set: { if !$0 { model.cancelDelete() } }
            ), presenting: model.deletePrompt) { prompt in
                Button(HistoryText.deleteConfirm, role: .destructive) { Task { await model.confirmDelete(prompt) } }
                Button(HistoryText.cancel, role: .cancel) { model.cancelDelete() }
            } message: { prompt in
                Text(prompt.message)
            }
        }
    }
}

/// El detalle de una sesión, empujado sobre la lista.
private struct SessionDetail: View {
    @Bindable var model: HistoryModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if model.isIncomplete {
                    Label(HistoryText.incomplete, systemImage: "pause.fill")
                        .scaledFont(11, .bold)
                        .foregroundStyle(Theme.accentLight)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Theme.accent.opacity(0.18), in: .capsule)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(Array(model.cards.enumerated()), id: \.offset) { index, card in
                    // Sin acciones, solo lectura: los controles salen al tocar «Editar».
                    ExerciseCardView(card: card, toggle: { model.toggleCard(index) }, actions: card.isEditable ? actions(index) : nil)
                }
            }
            .padding()
        }
        .keyboardDismissal()
        // Mientras se edita, «Cancelar» y «OK» sustituyen a la flecha; sin ella, iOS apaga también
        // volver deslizando, y nada se pierde sin preguntar.
        .navigationBarBackButtonHidden(model.isEditing)
        .toolbar {
            if model.isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button(HistoryText.cancel) { model.cancelEditing() }
                        .accessibilityIdentifier("session-cancel")
                        // Colgado de «Cancelar»: en iOS 26 el diálogo sale como globo que apunta a
                        // su vista. `presenting` le pasa el aviso a la acción: SwiftUI lo cierra antes.
                        .confirmationDialog(HistoryText.discardTitle, isPresented: Binding(
                            get: { model.discardPrompt != nil }, set: { if !$0 { model.keepEditing() } }
                        ), titleVisibility: .visible, presenting: model.discardPrompt) { prompt in
                            Button(HistoryText.discardConfirm, role: .destructive) { model.discardChanges(prompt) }
                            Button(HistoryText.keepEditing, role: .cancel) { model.keepEditing() }
                        }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(HistoryText.done) { Task { await model.finishEditing() } }
                        .accessibilityIdentifier("session-done")
                }
            } else {
                ToolbarItem(placement: .primaryAction) {
                    Button(HistoryText.edit) { model.startEditing() }
                        .accessibilityIdentifier("session-edit")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if model.isIncomplete && !model.isEditing {
                BottomActions(primary: {
                    Button { Task { await model.completeWorkout() } } label: { Text(HistoryText.completeWorkout).frame(maxWidth: .infinity) }
                        .buttonStyle(.glassPill())
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
            chooseRep: { value, series in model.chooseRep(value, series: series, at: index) }
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
                Text(row.day).scaledFont(20, .bold).monospacedDigit().foregroundStyle(Theme.text)
                Text(row.month).scaledFont(9.5, .semibold).tracking(0.4).foregroundStyle(Theme.textMuted)
            }
            .frame(minWidth: 40)
            Rectangle().fill(Theme.border).frame(width: 1, height: 32)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    RoutineBadge(text: row.routine, color: Theme.color(row.tint) ?? Theme.textSecondary)
                    if let relative = row.relative {
                        Text(relative).scaledFont(11).foregroundStyle(Theme.textSecondary)
                    }
                    if row.isIncomplete {
                        Image(systemName: "pause.fill").scaledFont(10).foregroundStyle(Theme.accent).accessibilityLabel(HistoryText.incomplete)
                    }
                }
                Text(row.summary).scaledFont(12).foregroundStyle(Theme.textSecondary).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .card(background: row.isIncomplete ? Theme.accent.opacity(0.07) : Theme.surface,
              border: row.isIncomplete ? Theme.accent.opacity(0.35) : nil,
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
            .scaledFont(9.5, .bold)
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
