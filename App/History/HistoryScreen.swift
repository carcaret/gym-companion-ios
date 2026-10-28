import Domain
import Presentation
import SwiftUI
import ViewModels

/// La pestaña Historial: la lista de sesiones y el detalle de una. Solo pinta `HistoryModel`.
struct HistoryScreen: View {
    @Bindable var model: HistoryModel
    let sync: SyncModel
    /// Para los avisos de la hoja de editar (`CompositionRoot.noticeDuration`).
    let noticeDuration: Duration

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
                SessionDetail(model: model, sync: sync, noticeDuration: noticeDuration)
                    .syncToolbar {
                        Button(HistoryText.edit) { model.startEditing() }
                            .accessibilityIdentifier("session-edit")
                    }
                    .navigationTitle(model.detailTitle)
                    .navigationSubtitle(model.detailSubtitle)
                    .navigationBarTitleDisplayMode(.inline)
                    .screenBackground()
            }
    }

    @ViewBuilder
    private var list: some View {
        if model.rows.isEmpty {
            ContentUnavailableView(HistoryText.empty, systemImage: "list.clipboard", description: Text(HistoryText.emptyMessage))
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
                                    .tint(Theme.actionRed)
                            }
                            // Colgado de su fila, como quitar un ejercicio del entreno (repaso de la
                            // HIG, 2026-10-28): el botón de deslizar desaparece al tocarlo, la fila no.
                            // `presenting` le pasa el aviso a la acción: SwiftUI cierra el globo (y lo
                            // descarta) antes de ejecutarla.
                            .confirmationDialog(model.deletePrompt?.title ?? "", isPresented: Binding(
                                get: { model.deletePrompt?.date == row.date }, set: { if !$0 { model.cancelDelete() } }
                            ), titleVisibility: .visible, presenting: model.deletePrompt) { prompt in
                                Button(HistoryText.deleteSession, role: .destructive) { Task { await model.confirmDelete(prompt) } }
                                Button(HistoryText.cancel, role: .cancel) { model.cancelDelete() }
                            } message: { prompt in
                                Text(prompt.message)
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
            // La vibración al pasar el umbral ya la pone iOS (comprobado en el iPhone, 2026-10-27).
            .refreshable { await sync.pullToRefresh() }
        }
    }
}

/// El detalle de una sesión, empujado sobre la lista: de solo lectura. «Editar» abre la sesión en
/// una hoja (`SessionEditor`), como un contacto o un evento del Calendario (2026-10-27): la hoja
/// tapa las pestañas y la flecha, así que nada saca la sesión a medias y se pierde sin preguntar.
private struct SessionDetail: View {
    @Bindable var model: HistoryModel
    let sync: SyncModel
    let noticeDuration: Duration

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
                SessionCards(model: model)
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            if model.isIncomplete {
                BottomActions(primary: {
                    Button { Task { await model.completeWorkout() } } label: { Text(HistoryText.completeWorkout).frame(maxWidth: .infinity) }
                        .buttonStyle(.glassPill())
                })
            }
        }
        // Deslizarla hacia abajo es cancelar: sin cambios, se cierra; con cambios, no se deja.
        .sheet(isPresented: Binding(get: { model.isEditing }, set: { if !$0 { model.cancelEditing() } })) {
            NavigationStack { SessionEditor(model: model) }
                // Lo que cuelga de la raíz queda debajo de la hoja: avisos y conflicto, aquí.
                .syncPresentation(sync, noticeDuration: noticeDuration)
        }
    }
}

/// Las tarjetas de la sesión: de solo lectura en el detalle, editables en la hoja.
private struct SessionCards: View {
    @Bindable var model: HistoryModel

    var body: some View {
        ForEach(Array(model.cards.enumerated()), id: \.offset) { index, card in
            ExerciseCardView(card: card, toggle: { model.toggleCard(index) }, actions: card.isEditable ? actions(index) : nil)
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

/// La hoja de editar una sesión: la ✕ y la ✓, y con cambios no se cierra deslizando.
private struct SessionEditor: View {
    @Bindable var model: HistoryModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) { SessionCards(model: model) }
                .padding()
        }
        .keyboardDismissal()
        .screenBackground()
        .navigationTitle(model.detailTitle)
        .navigationSubtitle(model.detailSubtitle)
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(model.hasChanges)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                // ✕ y ✓ de iOS 26, como todas las hojas de la app (decisión del usuario, 2026-10-28).
                Button(role: .close) { model.cancelEditing() }
                    .accessibilityIdentifier("session-cancel")
                    // Colgado de la ✕: en iOS 26 el diálogo sale como globo que apunta a su vista, y
                    // se cierra tocando fuera (sigue editando).
                    .confirmationDialog(HistoryText.discardTitle, isPresented: Binding(
                        get: { model.isDiscardPromptPresented }, set: { if !$0 { model.keepEditing() } }
                    ), titleVisibility: .visible) {
                        Button(HistoryText.discardConfirm, role: .destructive) { model.discardChanges() }
                        Button(HistoryText.keepEditing, role: .cancel) { model.keepEditing() }
                    }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm) { Task { await model.finishEditing() } }
                    .disabled(!model.hasChanges)
                    .accessibilityIdentifier("session-done")
            }
        }
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
                Text(row.month).scaledFont(11, .semibold).tracking(0.4).foregroundStyle(Theme.textSecondary)
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
                        Image(systemName: "pause.fill").scaledFont(11).foregroundStyle(Theme.accent).accessibilityLabel(HistoryText.incomplete)
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
            .scaledFont(11, .bold)
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
