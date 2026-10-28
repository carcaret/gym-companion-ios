import SwiftUI

/// La pila de navegación de cada pestaña y de cada hoja: la flecha de volver, la ✕ y los botones
/// de la barra, sin teñir. En iOS 26 el color es para el fondo de la acción principal, no para
/// símbolos ni texto (repaso de la HIG, 2026-10-28; las hojas se quedaron con la ✕ azul hasta el
/// mismo día). El contenido conserva el azul de la raíz; la nube y la ✓ llevan sus propios colores.
struct AppNavigationStack<Content: View>: View {
    private let path: Binding<NavigationPath>?
    private let content: Content

    /// La de una pestaña, con su pila (`RootView.paths`).
    init(path: Binding<NavigationPath>, @ViewBuilder content: () -> Content) {
        self.path = path
        self.content = content()
    }

    /// La de una hoja.
    init(@ViewBuilder content: () -> Content) {
        self.path = nil
        self.content = content()
    }

    var body: some View {
        Group {
            if let path {
                NavigationStack(path: path) { tintedContent }
            } else {
                NavigationStack { tintedContent }
            }
        }
        .tint(Theme.text)
    }

    private var tintedContent: some View {
        content.tint(Theme.accentLight)
    }
}

extension View {
    /// La ✓ de una hoja: la acción principal, la única de la barra con color, el azul de los botones
    /// principales (`.glassPill`).
    func confirmTint() -> some View {
        tint(Theme.accent)
    }
}
