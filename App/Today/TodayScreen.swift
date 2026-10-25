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
            // La vista previa entra empujada sobre el selector: se vuelve con la flecha de la
            // barra o deslizando desde el borde, como en cualquier app de iOS.
            case .selector, .preview: selector.navigationTitle(TodayText.selectorTitle)
            case .active: ActiveWorkoutView(model: model).navigationTitle(model.title)
            case .completed: completed.navigationTitle(model.title)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.appear() }
        .navigationDestination(isPresented: Binding(get: { isPreviewing }, set: { if !$0 { model.backToSelector() } })) {
            preview
                .navigationTitle(model.title)
                .navigationBarTitleDisplayMode(.inline)
                .screenBackground()
        }
    }

    private var isPreviewing: Bool {
        if case .preview = model.stage { true } else { false }
    }

    private var selector: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text(TodayText.selectorPrompt)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.bottom, 8)
                ForEach(model.routineRows, id: \.id) { row in
                    Button { model.select(row.id) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.color(row.tint) ?? Theme.text)
                            Text(row.subtitle).font(.system(size: 12)).foregroundStyle(Theme.textSecondary).lineLimit(2)
                            if let note = row.pendingNote {
                                Text(note).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.accent).padding(.top, 4)
                            }
                        }
                        .card(padding: 20, stripe: Theme.color(row.tint))
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("routine-\(row.id.rawValue)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
    }

    private var preview: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(model.previewCards.enumerated()), id: \.offset) { index, card in
                    ExerciseCardView(card: card, toggle: { model.togglePreviewCard(index) })
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            BottomActions(primary: {
                Button { Task { await model.start() } } label: { Text(TodayText.start).frame(maxWidth: .infinity) }
                    .buttonStyle(.pill())
                    .accessibilityIdentifier("start-workout")
            })
        }
    }

    private var completed: some View {
        ScrollView {
            VStack(spacing: 12) {
                Label(TodayText.completedStatus, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .medium))
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
                Button { model.backFromCompleted() } label: {
                    Label(TodayText.backToRoutines, systemImage: "chevron.left").frame(maxWidth: .infinity)
                }
                .buttonStyle(.pill(.secondary))
                .accessibilityIdentifier("back-to-routines")
                .padding(.top, 4)
            }
            .padding(16)
        }
    }
}

/// La fila de botones fija abajo, encima de la barra de pestañas: uno secundario a su tamaño y el
/// principal con el resto del ancho, o solo el principal a todo el ancho.
struct BottomActions<Secondary: View, Primary: View>: View {
    @ViewBuilder let secondary: Secondary
    @ViewBuilder let primary: Primary

    var body: some View {
        HStack(spacing: 12) {
            secondary
            primary
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Theme.background)
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
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(isSkipped ? Theme.textMuted : Theme.text)
            Text(subtitle).font(.system(size: 12)).foregroundStyle(isSkipped ? Theme.textMuted : Theme.textSecondary)
        }
        .card(background: isSkipped ? Theme.skipTint : Theme.surface)
    }
}
