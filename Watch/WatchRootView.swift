import SwiftUI
import ViewModels
import WatchKit

/// La app del reloj, según en qué punto está el entreno. Mientras se mide, tres páginas, en el
/// orden de Entreno: los controles, el entreno y la música (la vista del sistema).
struct WatchRootView: View {
    @Bindable var model: WatchModel

    var body: some View {
        switch model.screen {
        case .message(let text):
            MessageView(text: text)
        case .ready(let ready):
            ReadyView(ready: ready) {
                Task { await model.start() }
            }
        case .workout:
            TabView(selection: $model.tab) {
                ControlsPage(model: model)
                    .tag(WatchModel.Tab.controls)
                WorkoutPage(model: model)
                    .tag(WatchModel.Tab.workout)
                NowPlayingView()
                    .tag(WatchModel.Tab.music)
            }
            .tabViewStyle(.page)
        case .summary(let summary):
            SummaryView(summary: summary) {
                model.dismissSummary()
            }
        }
    }
}
