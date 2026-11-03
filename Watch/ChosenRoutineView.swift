import Presentation
import SwiftUI
import ViewModels

/// La rutina elegida en la lista: su nombre, sus ejercicios y «Empezar» (`ReadyView`), que mide en
/// seguida. Con el entreno de hoy ya terminado, antes pregunta si sustituirlo, como en el iPhone.
/// Es su propia vista, que lee el modelo: empujada, así le llegan los cambios.
struct ChosenRoutineView: View {
    let model: WatchModel

    var body: some View {
        if let ready = model.chosen {
            ReadyView(ready: ready) {
                Task { await model.requestStartChosen() }
            }
            .alert(model.replacePrompt?.title ?? "",
                   isPresented: Binding(presentedWhile: { model.replacePrompt != nil }, onDismiss: { model.cancelReplace() }),
                   presenting: model.replacePrompt) { prompt in
                Button(TodayText.replaceConfirm, role: .destructive) { Task { await model.confirmReplace(prompt) } }
                Button(FormText.cancel, role: .cancel) { model.cancelReplace() }
            } message: { prompt in
                Text(prompt.message)
            }
        }
    }
}
