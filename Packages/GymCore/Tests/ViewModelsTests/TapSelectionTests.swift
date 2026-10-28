import Testing
import ViewModels

// El bocadillo de «Últimas sesiones» y de las gráficas de Gráficas: un toque en otra barra cambia
// el bocadillo directamente (decisión del usuario, 2026-10-28; antes hacían falta dos toques).
@Suite("El bocadillo de una gráfica")
struct TapSelectionTests {
    @Test("un toque en una barra enseña su bocadillo")
    func tapShows() {
        var selection = TapSelection<Int>()
        selection.tap(2)
        #expect(selection.selected == 2)
    }

    @Test("un toque en otra barra cambia el bocadillo directamente")
    func tapAnotherSwitches() {
        var selection = TapSelection(2)
        selection.tap(4)
        #expect(selection.selected == 4)
    }

    @Test("un toque en la barra que ya se ve cierra el bocadillo")
    func tapSameCloses() {
        var selection = TapSelection(2)
        selection.tap(2)
        #expect(selection.selected == nil)
    }

    @Test("un toque donde no hay nada que enseñar cierra el bocadillo")
    func tapNothingCloses() {
        var selection = TapSelection(2)
        selection.tap(nil)
        #expect(selection.selected == nil)
    }

    @Test("se acaba el tiempo del bocadillo que se ve: se cierra")
    func expireCloses() {
        var selection = TapSelection(2)
        selection.expire(2)
        #expect(selection.selected == nil)
    }

    // El fallo de los dos toques: el temporizador de la primera barra, al cancelarse por el toque
    // en la segunda, cerraba el bocadillo de la segunda nada más salir.
    @Test("se acaba el tiempo de un bocadillo anterior: el de ahora sigue")
    func expireOldKeepsCurrent() {
        var selection = TapSelection(2)
        selection.tap(4)
        selection.expire(2)
        #expect(selection.selected == 4)
    }
}
