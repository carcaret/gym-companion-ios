import XCTest

/// Las zonas de toque miden al menos 44 × 44 pt, como pide Apple (repaso de la HIG, 2026-10-28):
/// en mitad del entreno, con el dedo sudado, es donde más se falla. Crecen sin montarse unas con
/// otras (condición del usuario) y sin cambiar lo que se ve.
final class TouchTargetTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLosControlesDeLaTarjetaMiden44YNoSeMontan() {
        let app = XCUIApplication.launchDemo()
        app.tabBars.buttons["Rutinas"].tap()
        XCTAssertTrue(app.buttons["routine-DIA1"].appears(timeout: 10))
        app.buttons["routine-DIA1"].tap()
        XCTAssertTrue(app.buttons["start-workout"].appears(timeout: 10))
        app.buttons["start-workout"].tap()
        let header = app.buttons["card-press_banca"].firstMatch
        XCTAssertTrue(header.appears(timeout: 10))
        if header.value as? String == "Plegado" { header.tap() }
        let firstSeries = app.descendants(matching: .any)["series-0"].firstMatch
        XCTAssertTrue(firstSeries.appears(timeout: 5))
        // Con una serie elegida salen los chips de reps, debajo de las series.
        firstSeries.tap()
        let chips = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'chip-'"))
        XCTAssertTrue(chips.firstMatch.appears(timeout: 5))

        var targets: [(String, CGRect)] = [("cabecera", header.frame)]
        for parameter in ["weight", "series", "target-reps"] {
            targets.append(("\(parameter)-minus", app.buttons["\(parameter)-minus"].firstMatch.frame))
            targets.append(("\(parameter)-field", app.textFields["\(parameter)-field"].firstMatch.frame))
            targets.append(("\(parameter)-plus", app.buttons["\(parameter)-plus"].firstMatch.frame))
        }
        let series = app.descendants(matching: .any).matching(NSPredicate(format: "identifier MATCHES 'series-[0-9]+'"))
        for index in 0..<series.count {
            targets.append(("series-\(index)", series.element(boundBy: index).frame))
        }
        for index in 0..<chips.count {
            let chip = chips.element(boundBy: index)
            targets.append((chip.identifier, chip.frame))
        }

        // El campo de texto da a VoiceOver la altura del texto, no la de su zona de toque: esa se
        // prueba al final, tocando junto al borde.
        for (name, frame) in targets where !name.hasSuffix("-field") {
            XCTAssertGreaterThanOrEqual(frame.height, 44, "\(name) mide \(frame.height) pt de alto")
            XCTAssertGreaterThanOrEqual(frame.width, 44, "\(name) mide \(frame.width) pt de ancho")
        }
        for (i, (name, frame)) in targets.enumerated() {
            for (other, otherFrame) in targets[(i + 1)...] {
                let overlap = frame.intersection(otherFrame)
                XCTAssertFalse(!overlap.isNull && overlap.width > 0.5 && overlap.height > 0.5, "\(name) se monta con \(other)")
            }
        }

        // La caja del peso se ve de 36 pt: tocar a 20 pt de su centro, ya fuera de la caja pero
        // dentro de los 44, abre el teclado.
        let field = app.textFields["weight-field"].firstMatch
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: 0, dy: -20)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.appears(timeout: 5), "Tocar junto al borde de la caja no abre el teclado")
    }

    /// En Progreso se toca toda la fila, no solo la línea de texto: la cabecera de «Ejercicios»,
    /// cada ejercicio, «Ver en Gráficas» y cada grupo muscular.
    @MainActor
    func testLasFilasDeProgresoSeTocanEnteras() {
        let app = XCUIApplication.launchDemo()
        app.tabBars.buttons["Progreso"].tap()
        let expand = app.buttons["stats-exercises"]
        XCTAssertTrue(expand.appears(timeout: 20))
        expand.tap()
        let row = app.buttons["stats-row-press_banca"]
        XCTAssertTrue(row.appears(timeout: 10))
        row.tap()
        let open = app.buttons["Ver en Gráficas"].firstMatch
        XCTAssertTrue(open.appears(timeout: 10))
        let group = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'stats-group-'")).firstMatch
        XCTAssertTrue(group.appears(timeout: 10))

        // Las secciones van a 16 pt de cada borde: la fila entera mide el ancho de la pantalla
        // menos 32.
        let sectionWidth = app.windows.firstMatch.frame.width - 32
        for (name, element) in [("Ejercicios", expand), ("el ejercicio", row), ("Ver en Gráficas", open), ("el grupo", group)] {
            XCTAssertGreaterThanOrEqual(element.frame.width, sectionWidth - 1, "\(name) solo se toca en \(element.frame.width) pt")
            XCTAssertGreaterThanOrEqual(element.frame.height, 44, "\(name) mide \(element.frame.height) pt de alto")
        }
    }
}
