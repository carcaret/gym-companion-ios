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
            // El selector, con el título grande que se encoge al desplazar, como la entrada de
            // las demás pestañas. El entreno en curso, en pequeño: un título largo con «En curso»
            // debajo, y el sitio es para las tarjetas (decisión del usuario, 2026-10-27).
            case .selector, .preview, .completed:
                selector.navigationTitle(TodayText.selectorTitle).navigationBarTitleDisplayMode(.large)
            case .active:
                ActiveWorkoutView(model: model).navigationTitle(model.title).navigationBarTitleDisplayMode(.inline)
            }
        }
        .navigationDestination(isPresented: Binding(get: { isPushed }, set: { if !$0 { model.backToSelector() } })) {
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
            .navigationBarTitleDisplayMode(.inline)
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
                .accessibilityIdentifier("routine-\(row.id.rawValue)")
                .cardRow()
            }
        }
        .listStyle(.plain)
        .screenBackground()
    }
}

/// El entreno terminado, empujado sobre el selector: se vuelve a las rutinas con la flecha de la
/// barra, deslizando desde el borde o tocando otra vez la pestaña (decisión del usuario,
/// 2026-10-27; antes no tenía ninguna forma de salir salvo la pestaña).
private struct WorkoutSummary: View {
    @Bindable var model: TodayModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Label(TodayText.completedStatus, systemImage: "checkmark.circle.fill")
                    .accessibilityIdentifier("workout-completed")
                    .scaledFont(14, .medium)
                    .foregroundStyle(Theme.text)
                    .symbolRenderingMode(.multicolor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Theme.greenTint, in: .rect(cornerRadius: Theme.radiusSmall))
                    .overlay { RoundedRectangle(cornerRadius: Theme.radiusSmall).strokeBorder(Theme.greenSoft.opacity(0.3)) }
                ForEach(Array(model.completedRows.enumerated()), id: \.offset) { _, row in
                    SummaryRowView(title: row.title, subtitle: row.subtitle, isSkipped: row.isSkipped)
                }
            }
            .padding(16)
        }
    }
}

/// La vista previa de una rutina, empujada sobre el selector.
private struct RoutinePreview: View {
    @Bindable var model: TodayModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(Array(model.previewCards.enumerated()), id: \.offset) { index, card in
                    ExerciseCardView(card: card, toggle: { model.togglePreviewCard(index) })
                }
            }
            .padding()
        }
        // Sin ejercicios (la primera vez): qué hacer, en vez de una pantalla en blanco.
        .overlay {
            if model.previewCards.isEmpty {
                ContentUnavailableView(TodayText.emptyRoutineTitle, systemImage: "dumbbell",
                                       description: Text(TodayText.emptyRoutineMessage))
            }
        }
        .safeAreaInset(edge: .bottom) {
            BottomActions(primary: {
                Button { Task { await model.requestStart() } } label: { Text(TodayText.start).frame(maxWidth: .infinity) }
                    .buttonStyle(.glassPill())
                    .accessibilityIdentifier("start-workout")
                    // Colgado del botón: en iOS 26 el diálogo sale como globo que apunta a su vista.
                    // `presenting` le pasa el aviso a la acción: SwiftUI lo cierra antes.
                    .confirmationDialog(model.replacePrompt?.title ?? "", isPresented: Binding(
                        get: { model.replacePrompt != nil }, set: { if !$0 { model.cancelReplace() } }
                    ), titleVisibility: .visible, presenting: model.replacePrompt) { prompt in
                        Button(TodayText.replaceConfirm, role: .destructive) { Task { await model.confirmReplace(prompt) } }
                        Button(TodayText.cancel, role: .cancel) { model.cancelReplace() }
                    } message: { prompt in
                        Text(prompt.message)
                    }
            })
        }
    }
}

/// La fila de botones fija abajo, encima de la barra de pestañas: el secundario y el principal a
/// partes iguales (se distinguen por el estilo, no por el tamaño: repaso de la HIG, 2026-10-28), o
/// solo el principal a todo el ancho. Píldoras de cristal
/// (`.glassPill`) sin fondo detrás: las tarjetas pasan por debajo al desplazarse.
struct BottomActions<Secondary: View, Primary: View>: View {
    @ViewBuilder let secondary: Secondary
    @ViewBuilder let primary: Primary

    /// El margen de la barra de pestañas de iOS 26, para que los dos cristales tengan el mismo
    /// ancho (decisión del usuario, 2026-10-27). iOS no lo da: medido en el iPhone 17 Pro del CI
    /// (21 pt; las tarjetas van a 16). Si cambia con otra versión de iOS, se vuelve a medir.
    private static var tabBarMargin: CGFloat { 21 }

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                secondary
                primary
            }
        }
        .padding(.horizontal, Self.tabBarMargin)
        .padding(.vertical, 8)
    }
}

extension BottomActions where Secondary == EmptyView {
    init(@ViewBuilder primary: () -> Primary) {
        self.init(secondary: { EmptyView() }, primary: primary)
    }
}

/// Una línea de un entreno terminado (también la usa el historial): una tarjeta compacta; la de
/// un ejercicio saltado, con el tinte rojo apagado de la PWA.
struct SummaryRowView: View {
    let title: String
    let subtitle: String
    let isSkipped: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).scaledFont(15, .semibold).foregroundStyle(isSkipped ? Theme.textSecondary : Theme.text)
            Text(subtitle).scaledFont(12).foregroundStyle(Theme.textSecondary)
        }
        .card(background: isSkipped ? Theme.skipTint : Theme.surface)
    }
}
