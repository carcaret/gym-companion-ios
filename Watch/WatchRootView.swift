import SwiftUI
import ViewModels

/// Un ejercicio por página; se pasa de uno a otro con la corona o deslizando.
struct WatchRootView: View {
    @Bindable var model: WatchModel

    var body: some View {
        switch model.content {
        case .message(let text):
            Text(text)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
        case .workout(let pages):
            TabView(selection: $model.page) {
                ForEach(pages) { page in
                    ExercisePageView(page: page)
                        .tag(page.id)
                }
            }
            .tabViewStyle(.verticalPage)
        }
    }
}
