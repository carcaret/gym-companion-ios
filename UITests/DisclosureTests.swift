import XCTest

/// Las tarjetas que se abren (`CardDisclosure`): VoiceOver dice si están desplegadas (antes
/// decía «seleccionado» al abrirlas).
final class DisclosureTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLaTarjetaDiceSiEstaDesplegada() {
        let app = XCUIApplication.launchDemo()
        app.startWorkout(timeout: 20)
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
