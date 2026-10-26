import XCTest

/// El aviso de abajo (`NoticeView`) es un elemento de accesibilidad con su texto: antes se veía en
/// pantalla pero no estaba en el árbol, y VoiceOver no lo podía leer al tocarlo (2026-10-26).
final class NoticeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Tocar el indicador de la sincronización dice el estado en el aviso; con `-demo` no hay GitHub.
    @MainActor
    func testTocarElIndicadorSacaElAviso() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()
        let indicator = app.buttons["sync-indicator"].firstMatch
        XCTAssertTrue(indicator.waitForExistence(timeout: 20))
        indicator.tap()
        // El aviso dura 2,5 s: se busca nada más tocar, sin capturas por medio.
        let notice = app.staticTexts.matching(identifier: "notice").firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 8))
        XCTAssertEqual(notice.label, "GitHub no configurado")
    }
}
