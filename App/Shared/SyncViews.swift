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
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task(id: notice) {
                            try? await Task.sleep(for: .seconds(2.5))
                            if sync.notice == notice { sync.notice = nil }
                        }
                }
            }
            .animation(.default, value: sync.notice)
            .confirmationDialog(SyncText.conflictTitle, isPresented: $sync.isConflictPresented, titleVisibility: .visible) {
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
        Label(notice.text, systemImage: symbol)
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect()
            .accessibilityIdentifier("notice")
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
