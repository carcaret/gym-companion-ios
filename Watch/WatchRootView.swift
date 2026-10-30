import SwiftUI
import ViewModels
import WatchKit

/// La app del reloj, según en qué punto está el entreno. Mientras se mide, tres páginas: la música
/// (la vista del sistema, como en Entreno), el entreno y los controles.
struct WatchRootView: View {
    @Bindable var model: WatchModel

    var body: some View {
        switch model.screen {
        case .message(let text):
            Text(text)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
        case .ready(let ready):
            ReadyView(ready: ready) {
                Task { await model.start() }
            }
        case .workout:
            TabView(selection: $model.tab) {
                NowPlayingView()
                    .tag(WatchModel.Tab.music)
                WorkoutPage(model: model)
                    .tag(WatchModel.Tab.workout)
                ControlsPage(model: model)
                    .tag(WatchModel.Tab.controls)
            }
            .tabViewStyle(.page)
        case .summary(let summary):
            SummaryView(summary: summary) {
                model.dismissSummary()
            }
        }
    }
}
