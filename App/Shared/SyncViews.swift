import Application
import Presentation
import SwiftUI
import ViewModels

/// El estado de la sincronización en la barra: un menú que lo dice y ofrece lo que toca
/// (sincronizar ahora, resolver el conflicto o configurar GitHub) y los ajustes.
struct SyncIndicator: View {
    let sync: SyncModel

    var body: some View {
        Menu {
            Section(sync.statusText) {
                switch sync.menuAction {
                case .syncNow:
                    Button(SyncText.syncNowLabel, systemImage: "arrow.triangle.2.circlepath") { Task { await sync.pullToRefresh() } }
                case .resolveConflict:
                    Button(SyncText.resolveConflictLabel, systemImage: "exclamationmark.triangle") { sync.resolveConflict() }
                case .configure:
                    Button(SyncText.configureLabel, systemImage: "gearshape") { sync.showSettings() }
                }
            }
            if sync.offersSettings {
                Button(SyncText.settingsLabel, systemImage: "gearshape") { sync.showSettings() }
            }
        } label: {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .symbolEffect(.pulse, isActive: sync.indicatorPulses)
        }
        .accessibilityIdentifier("sync-indicator")
        .accessibilityLabel(sync.statusText)
    }

    private var symbol: String {
        switch sync.status.state {
        case .ok: "checkmark.icloud"
        case .pending: sync.status.conflict ? "exclamationmark.icloud" : "icloud.and.arrow.up"
        case .disabled: "icloud.slash"
        }
    }

    /// Verde sincronizado, dorado pendiente, gris sin configurar (`.sync-indicator`).
    private var color: Color {
        switch sync.status.state {
        case .ok: Theme.green
        case .pending: Theme.gold
        case .disabled: Theme.textMuted
        }
    }

}

extension View {
    /// La nube en la barra. La lleva toda pantalla de una pila: la de entrada de cada pestaña y
    /// cada empujada, que trae su propia barra (antes solo salía en la de entrada, 2026-10-27). Va
    /// donde se empuja la pantalla, no dentro de ella: Gráficas es la entrada de su pestaña y
    /// también se empuja desde Progreso. El modelo llega por el entorno (`RootView`).
    func syncToolbar() -> some View {
        modifier(SyncToolbar())
    }
}

private struct SyncToolbar: ViewModifier {
    @Environment(SyncModel.self) private var sync

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SyncIndicator(sync: sync)
            }
        }
    }
}

/// Los avisos y diálogos de la sincronización, en la raíz y en la hoja de los ajustes (sus botones
/// también avisan y pueden abrir el conflicto, y lo que cuelga de la raíz queda debajo de la hoja).
struct SyncPresentation: ViewModifier {
    @Bindable var sync: SyncModel
    /// Lo que dura el aviso (`CompositionRoot.noticeDuration`).
    let noticeDuration: Duration
    /// El de la raíz se apaga mientras la hoja de los ajustes está abierta: lo pinta la hoja.
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            // Arriba, sobre la barra de navegación y debajo de la Dynamic Island, como los avisos del
            // sistema: abajo tapaba las píldoras de acción, y casi todos los avisos hablan de la
            // sincronización, cuya nube está arriba (decisión del usuario, 2026-10-27). Los
            // márgenes dejan libres los botones de la barra, también la nube.
            .overlay(alignment: .top) {
                if isActive, let notice = sync.notice {
                    NoticeView(notice: notice)
                        .padding(.horizontal, 56)
                        .padding(.top, 4)
                        // Hacia arriba se va en cuanto el dedo sube, como un aviso del sistema, sin
                        // esperar a soltar: un arrastre que acaba fuera de la pantalla no termina.
                        .gesture(DragGesture(minimumDistance: 10).onChanged { drag in
                            if drag.translation.height < -10 { sync.notice = nil }
                        })
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .task(id: notice) {
                            try? await Task.sleep(for: noticeDuration)
                            if sync.notice == notice { sync.notice = nil }
                        }
                }
            }
            .animation(.default, value: sync.notice)
            // Alerta y no confirmationDialog: se abre desde el menú del indicador, que ya se ha
            // cerrado, o al tirar de la lista (en iOS 26 el diálogo sería un globo sin de qué salir).
            .alert(SyncText.conflictTitle, isPresented: whileActive($sync.isConflictPresented)) {
                Button(SyncText.keepLocalLabel) { Task { await sync.keepLocal() } }
                Button(SyncText.keepRemoteLabel) { Task { await sync.keepRemote() } }
                Button(SyncText.cancelLabel, role: .cancel) { sync.cancelConflict() }
            } message: {
                Text(SyncText.conflictMessage)
            }
            .alert(SyncText.savedLocallyTitle, isPresented: whileActive($sync.isSavedLocallyPresented)) {
                Button(SyncText.understood) {}
            } message: {
                Text(SyncText.savedLocallyMessage)
            }
    }

    private func whileActive(_ isPresented: Binding<Bool>) -> Binding<Bool> {
        Binding(get: { isActive && isPresented.wrappedValue }, set: { isPresented.wrappedValue = $0 })
    }
}

extension View {
    func syncPresentation(_ sync: SyncModel, noticeDuration: Duration, isActive: Bool = true) -> some View {
        modifier(SyncPresentation(sync: sync, noticeDuration: noticeDuration, isActive: isActive))
    }
}

/// El toast de la PWA, de cristal: flota sobre el contenido, como la barra de pestañas y los
/// botones de abajo (2026-10-27). Un texto largo pasa a dos líneas.
struct NoticeView: View {
    let notice: Notice

    var body: some View {
        NoticeLabel(notice: notice)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .scaledFont(13, .medium)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: .capsule)
            // Un solo elemento con su texto: si no, no aparecía en el árbol de accesibilidad
            // (ni VoiceOver lo podía leer al tocarlo ni los tests lo encontraban).
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(notice.text)
            .accessibilityAddTraits(.isStaticText)
            .accessibilityIdentifier("notice")
            .onAppear { AccessibilityNotification.Announcement(notice.text).post() }
    }
}

/// El icono y el texto de un aviso, con el color de su tipo: en el aviso que flota y, en los
/// ajustes, debajo de «Probar conexión».
struct NoticeLabel: View {
    let notice: Notice

    var body: some View {
        Label {
            Text(notice.text).foregroundStyle(Theme.text)
        } icon: {
            Image(systemName: symbol).foregroundStyle(color)
        }
    }

    private var color: Color {
        switch notice.kind {
        case .info: Theme.textSecondary
        case .success: Theme.green
        case .warning: Theme.gold
        case .error: Theme.red
        }
    }

    private var symbol: String {
        switch notice.kind {
        case .info: "info.circle"
        case .success: "checkmark.circle"
        case .warning: "exclamationmark.triangle"
        case .error: "xmark.octagon"
        }
    }
}
