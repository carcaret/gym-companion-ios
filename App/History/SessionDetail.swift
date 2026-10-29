import Domain
import Presentation
import SwiftUI
import ViewModels

/// El detalle de una sesión, empujado sobre la lista: de solo lectura. «Editar» abre la sesión en
/// una hoja (`SessionEditor`), como un contacto o un evento del Calendario (2026-10-27): la hoja
/// tapa las pestañas y la flecha, así que nada saca la sesión a medias y se pierde sin preguntar.
struct SessionDetail: View {
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
        .sheet(isPresented: Binding(get: { model.isEditing }, set: { if !$0 { model.requestClose() } })) {
            NavigationStack { SessionEditor(model: model) }
                // Lo que cuelga de la raíz queda debajo de la hoja: avisos y conflicto, aquí.
                .syncPresentation(sync, noticeDuration: noticeDuration)
        }
    }
}

/// Las tarjetas de la sesión: de solo lectura en el detalle, editables en la hoja.
struct SessionCards: View {
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
