import SwiftUI

/// Una sección con el aspecto de las de lista de iOS 26, fuera de una `List`: la cabecera encima,
/// las filas en un bloque redondeado y el pie debajo.
struct ListSection<Content: View, Header: View, Footer: View>: View {
    @ViewBuilder let content: Content
    @ViewBuilder let header: Header
    @ViewBuilder let footer: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header.padding(.horizontal, 16)
            VStack(alignment: .leading, spacing: 0) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface, in: .rect(cornerRadius: Theme.radius))
            footer.padding(.horizontal, 16)
        }
    }
}

extension ListSection where Footer == EmptyView {
    init(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> Header) {
        self.init(content: content, header: header, footer: { EmptyView() })
    }
}

/// La línea fina entre dos filas de una sección, con su sangría a la izquierda, como en iOS.
struct ListSeparator: View {
    let inset: CGFloat

    var body: some View {
        Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.5).padding(.leading, inset)
    }
}
