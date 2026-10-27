import XCTest

extension XCUIElement {
    /// Como `waitForExistence(timeout:)`, con el mismo tiempo máximo y el mismo resultado, pero mira
    /// primero si el elemento ya está: `waitForExistence` hace su primera comprobación al cabo de un
    /// segundo aunque el elemento esté en pantalla desde el principio (1,04 s de media en el CI, unas
    /// 50 veces por mitad; medido el 2026-10-26).
    @MainActor
    func appears(timeout: TimeInterval) -> Bool {
        exists || waitForExistence(timeout: timeout)
    }
}
