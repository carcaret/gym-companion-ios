import Application
import Presentation
import SwiftUI
import ViewModels

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
            .accessibilityIdentifier(AccessibilityID.notice)
            .onAppear { AccessibilityNotification.Announcement(notice.text).post() }
    }
}

/// El icono y el texto de un aviso, con el color de su tipo: en el aviso que flota y, en los
/// ajustes, debajo de los campos.
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
