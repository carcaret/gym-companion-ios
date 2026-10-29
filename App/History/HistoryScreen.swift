import Domain
import Presentation
import SwiftUI
import ViewModels

/// La pestaña Historial: la lista de sesiones y el detalle de una. Solo pinta `HistoryModel`.
struct HistoryScreen: View {
    @Bindable var model: HistoryModel
    let sync: SyncModel

    var body: some View {
        list
            .navigationTitle(HistoryText.title)
            // El detalle entra empujado, como en cualquier app de iOS: se vuelve también con el
            // botón de la barra o deslizando desde el borde.
            .navigationDestination(isPresented: Binding(
                get: { model.selectedDate != nil }, set: { if !$0 { model.back() } }
            )) {
                // Su propia vista, que lee el modelo: construida aquí, el cambio le llegaba sin la
                // animación y las tarjetas se abrían de golpe (vídeo del CI, 2026-10-27).
                SessionDetail(model: model, sync: sync)
                    .syncToolbar {
                        Button(HistoryText.edit) { model.startEditing() }
                            .accessibilityIdentifier("session-edit")
                    }
                    .navigationTitle(model.detailTitle)
                    .navigationSubtitle(model.detailSubtitle)
                    .screenBackground()
            }
    }

    @ViewBuilder
    private var list: some View {
        if model.rows.isEmpty {
            ContentUnavailableView(HistoryText.empty, systemImage: "list.clipboard", description: Text(HistoryText.emptyMessage))
        } else {
            // Por meses, como Fotos o Fitness (2026-10-27). El mes es una fila y no la cabecera de
            // la sección: en una lista `.plain` la cabecera se queda fija debajo de la barra, y eran
            // dos franjas arriba. Se va al desplazar, como en Mail o Ajustes; cada sesión ya dice
            // su día y su mes (decisión del usuario, 2026-10-28).
            List(model.sections) { section in
                Section {
                    MonthHeader(title: section.title)
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
                                Button(FormText.cancel, role: .cancel) { model.cancelDelete() }
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
