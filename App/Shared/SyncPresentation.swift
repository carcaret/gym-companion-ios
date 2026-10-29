import Application
import Presentation
import SwiftUI
import ViewModels

/// Los avisos y diálogos de la sincronización, en la raíz y en la hoja de los ajustes (sus botones
/// también avisan y pueden abrir el conflicto, y lo que cuelga de la raíz queda debajo de la hoja).
struct SyncPresentation: ViewModifier {
    @Bindable var sync: SyncModel
    /// El de la raíz se apaga mientras la hoja de los ajustes está abierta: lo pinta la hoja.
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            // Arriba, sobre la barra de navegación y debajo de la Dynamic Island, como los avisos del
            // sistema: abajo tapaba las píldoras de acción, y casi todos los avisos hablan de la
            // sincronización, cuya nube está arriba (decisión del usuario, 2026-10-27). Los
            // márgenes dejan libres los botones de la barra: la nube llega a 63 pt del borde
            // (medido en el vídeo del CI), y un aviso largo no la tapa.
            .overlay(alignment: .top) {
                if isActive, let notice = sync.notice {
                    NoticeView(notice: notice)
                        .padding(.horizontal, 68)
                        .padding(.top, 4)
                        // Hacia arriba se va en cuanto el dedo sube, como un aviso del sistema, sin
                        // esperar a soltar: un arrastre que acaba fuera de la pantalla no termina.
                        .gesture(DragGesture(minimumDistance: 10).onChanged { drag in
                            if drag.translation.height < -10 { sync.dismissNotice() }
                        })
                        .onTapGesture { sync.dismissNotice() }
                        .accessibilityAction(named: Notice.dismissLabel) { sync.dismissNotice() }
                        // Con «Reducir movimiento», aparece fundido en vez de bajar.
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                        // Un error espera a que lo cierren; lo demás se va solo (repaso de la HIG,
                        // 2026-10-28: «Sin conexión…» se iba a los 2,5 s).
                        .task(id: notice) {
                            guard !notice.staysUntilDismissed else { return }
                            try? await Task.sleep(for: sync.noticeDuration)
                            sync.expire(notice)
                        }
                }
            }
            .animation(.default, value: sync.notice)
            // Alerta y no confirmationDialog: se abre desde el menú del indicador, que ya se ha
            // cerrado, o al tirar de la lista (en iOS 26 el diálogo sería un globo sin de qué salir).
            .alert(SyncText.conflictTitle, isPresented: whileActive($sync.isConflictPresented)) {
                Button(SyncText.keepLocalLabel) { Task { await sync.keepLocal() } }
                // Lo de este iPhone se pierde: en rojo.
                Button(SyncText.keepRemoteLabel, role: .destructive) { Task { await sync.keepRemote() } }
                Button(FormText.cancel, role: .cancel) { sync.cancelConflict() }
            } message: {
                Text(SyncText.conflictMessage)
            }
    }

    private func whileActive(_ isPresented: Binding<Bool>) -> Binding<Bool> {
        Binding(get: { isActive && isPresented.wrappedValue }, set: { isPresented.wrappedValue = $0 })
    }
}

extension View {
    func syncPresentation(_ sync: SyncModel, isActive: Bool = true) -> some View {
        modifier(SyncPresentation(sync: sync, isActive: isActive))
    }
}
