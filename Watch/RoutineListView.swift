import Presentation
import SwiftUI
import ViewModels

/// Sin entreno en curso: las rutinas, para empezarlo en el reloj. Cada una en su tarjeta, con el
/// filete y el nombre de su color, como las de Rutinas en el iPhone; solo el nombre (decisión del
/// usuario, 2026-11-03). Tocar una abre su pantalla de «Empezar», que se cierra con la flecha.
struct RoutineListView: View {
    let model: WatchModel
    let routines: [WatchModel.RoutineRow]

    var body: some View {
        NavigationStack {
            List(routines) { routine in
                Button {
                    model.choose(routine.id)
                } label: {
                    Text(routine.name)
                        .font(.headline)
                        .foregroundStyle(Theme.color(routine.tint) ?? Theme.text)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .listRowBackground(card(stripe: Theme.color(routine.tint)))
                .accessibilityIdentifier(AccessibilityID.watchRoutine(routine.id.rawValue))
            }
            .navigationTitle(WatchText.routines)
            .navigationDestination(isPresented: Binding(presentedWhile: { model.chosenRoutine != nil }, onDismiss: { model.closeChosen() })) {
                ChosenRoutineView(model: model)
            }
        }
    }

    private func card(stripe: Color?) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.watchRowRadius, style: .continuous)
        return shape
            .fill(Theme.surface2)
            .overlay(alignment: .leading) {
                if let stripe { Rectangle().fill(stripe).frame(width: 3) }
            }
            .clipShape(shape)
    }
}
