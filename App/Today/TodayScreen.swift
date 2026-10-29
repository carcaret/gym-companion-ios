import Domain
import Presentation
import SwiftUI
import ViewModels

/// La pestaña Rutinas: selector, vista previa, entreno en curso y entreno terminado. Solo pinta
/// `TodayModel`.
struct TodayScreen: View {
    @Bindable var model: TodayModel

    var body: some View {
        Group {
            switch model.stage {
            // La vista previa y el entreno terminado entran empujados sobre el selector: se vuelve
            // con la flecha de la barra o deslizando desde el borde, como en cualquier app de iOS.
            case .selector, .preview, .completed:
                selector.navigationTitle(TodayText.selectorTitle)
            case .active:
                ActiveWorkoutView(model: model).navigationTitle(model.title)
            }
        }
        .navigationDestination(isPresented: Binding(presentedWhile: { isPushed }, onDismiss: { model.backToSelector() })) {
            // Su propia vista, que lee el modelo: construida aquí, el cambio le llegaba sin la
            // animación y las tarjetas se abrían de golpe (vídeo del CI, 2026-10-27).
            Group {
                if model.stage == .completed {
                    WorkoutSummary(model: model)
                } else {
                    RoutinePreview(model: model)
                }
            }
            .syncToolbar()
            .navigationTitle(model.title)
            .navigationSubtitle(model.subtitle ?? "")
            .screenBackground()
        }
    }

    /// La vista previa o el entreno terminado, empujados sobre el selector.
    private var isPushed: Bool {
        switch model.stage {
        case .preview, .completed: true
        case .selector, .active: false
        }
    }

    /// Una `List` de iOS con las tarjetas de la PWA como filas (`cardRow`).
    private var selector: some View {
        // Sin la frase «Selecciona una rutina para entrenar» de la PWA: el título y las tarjetas
        // ya lo dicen (decisión del usuario, 2026-10-27).
        List {
            ForEach(model.routineRows, id: \.id) { row in
                Button { model.select(row.id) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.title)
                            .scaledFont(15, .semibold)
                            .foregroundStyle(Theme.color(row.tint) ?? Theme.text)
                        Text(row.subtitle).scaledFont(12).foregroundStyle(Theme.textSecondary).lineLimit(2)
                        if let note = row.pendingNote {
                            Text(note).scaledFont(12, .medium).foregroundStyle(Theme.accent).padding(.top, 4)
                        }
                    }
                    .card(padding: 20, stripe: Theme.color(row.tint))
                    .contentShape(.rect)
                }
                .buttonStyle(.card)
                .accessibilityIdentifier(AccessibilityID.routine(row.id.rawValue))
                .cardRow()
            }
        }
        .listStyle(.plain)
        .screenBackground()
    }
}
