import Application
import Presentation
import SwiftUI
import ViewModels

/// Botón con el estado de la sincronización; al tocarlo dice el estado o abre el conflicto.
struct SyncIndicator: View {
    let sync: SyncModel

    var body: some View {
        Button {
            sync.tapIndicator()
        } label: {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .symbolEffect(.pulse, isActive: sync.status.state == .pending)
        }
        .accessibilityIdentifier("sync-indicator")
        .accessibilityLabel(label)
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

    private var label: String {
        switch sync.status.state {
        case .ok: String(localized: "Sincronizado con GitHub")
        case .pending: sync.status.conflict ? String(localized: "Conflicto con GitHub") : String(localized: "Cambios pendientes de subir")
        case .disabled: String(localized: "GitHub no configurado")
        }
    }
}

/// Los avisos y diálogos de la sincronización, para ponerlos una vez en la raíz.
struct SyncPresentation: ViewModifier {
    @Bindable var sync: SyncModel

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let notice = sync.notice {
                    NoticeView(notice: notice)
                        .padding(.bottom, 96)  // por encima de la barra de pestañas
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task(id: notice) {
                            try? await Task.sleep(for: .seconds(2.5))
                            if sync.notice == notice { sync.notice = nil }
                        }
                }
            }
            .animation(.default, value: sync.notice)
            // Alerta y no confirmationDialog: no sale de un botón concreto (en iOS 26 el diálogo
            // sería un globo apuntando a la pantalla entera).
            .alert(SyncText.conflictTitle, isPresented: $sync.isConflictPresented) {
                Button(SyncText.keepLocalLabel) { Task { await sync.keepLocal() } }
                Button(SyncText.keepRemoteLabel) { Task { await sync.keepRemote() } }
                Button(SyncText.cancelLabel, role: .cancel) { sync.cancelConflict() }
            } message: {
                Text(SyncText.conflictMessage)
            }
            .alert(SyncText.savedLocallyTitle, isPresented: $sync.isSavedLocallyPresented) {
                Button(SyncText.understood) {}
            } message: {
                Text(SyncText.savedLocallyMessage)
            }
    }
}

extension View {
    func syncPresentation(_ sync: SyncModel) -> some View {
        modifier(SyncPresentation(sync: sync))
    }
}

/// El toast de la PWA.
struct NoticeView: View {
    let notice: Notice

    var body: some View {
        Label {
            Text(notice.text).foregroundStyle(Theme.text)
        } icon: {
            Image(systemName: symbol).foregroundStyle(color)
        }
            .font(.scaled(13, weight: .medium))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Theme.surface2, in: .rect(cornerRadius: Theme.radiusSmall))
            .overlay { RoundedRectangle(cornerRadius: Theme.radiusSmall).strokeBorder(Theme.border) }
            .shadow(color: .black.opacity(0.45), radius: 15, y: 8)
            .accessibilityIdentifier("notice")
            .onAppear { AccessibilityNotification.Announcement(notice.text).post() }
    }

    private var color: Color {
        switch notice.kind {
        case .info: Theme.textSecondary
        case .success: Theme.green
        case .saved: Theme.textMuted
        case .warning: Theme.gold
        case .error: Theme.red
        }
    }

    private var symbol: String {
        switch notice.kind {
        case .info: "info.circle"
        case .success: "checkmark.circle"
        case .saved: "square.and.arrow.down"
        case .warning: "exclamationmark.triangle"
        case .error: "xmark.octagon"
        }
    }
}
