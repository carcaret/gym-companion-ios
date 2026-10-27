import XCTest

/// Las tarjetas que se abren son `DisclosureGroup`: VoiceOver dice si están desplegadas (antes
/// decía «seleccionado» al abrirlas).
final class DisclosureTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLaTarjetaDiceSiEstaDesplegada() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()
        app.tabBars.buttons["Rutinas"].tap()
        XCTAssertTrue(app.buttons["routine-DIA1"].appears(timeout: 20))
        app.buttons["routine-DIA1"].tap()
        XCTAssertTrue(app.buttons["start-workout"].appears(timeout: 10))
        app.buttons["start-workout"].tap()
        let card = app.buttons["card-press_banca"].firstMatch
        XCTAssertTrue(card.appears(timeout: 10))

        let before = card.value as? String
        XCTAssertTrue(["Plegado", "Desplegado"].contains(before), "Valor de VoiceOver: \(before ?? "ninguno")")
        card.tap()
        let after = before == "Plegado" ? "Desplegado" : "Plegado"
        let changed = expectation(for: NSPredicate(format: "value == %@", after), evaluatedWith: card)
        wait(for: [changed], timeout: 5)
        XCTAssertFalse(card.isSelected, "Una tarjeta abierta no está «seleccionada»")
    }
}
