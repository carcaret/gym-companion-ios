import Domain
import Testing

// Portados de tests/unit/routine-reorder.test.js de la PWA. En Swift los arrays son valores: que
// no se mute el original lo garantiza el lenguaje, pero se conservan los casos.

@Suite("reorderByIndex")
struct ReorderByIndexTests {
    @Test("mueve elemento hacia adelante (0 → 2 en array de 3)")
    func forward() { #expect(["a", "b", "c"].moving(from: 0, to: 2) == ["b", "c", "a"]) }

    @Test("mueve elemento hacia atrás (2 → 0 en array de 3)")
    func backward() { #expect(["a", "b", "c"].moving(from: 2, to: 0) == ["c", "a", "b"]) }

    @Test("mover a la misma posición devuelve array equivalente")
    func samePosition() { #expect(["a", "b", "c"].moving(from: 1, to: 1) == ["a", "b", "c"]) }

    @Test("no muta el array original (inmutabilidad)")
    func immutable() {
        let original = ["a", "b", "c"]
        _ = original.moving(from: 0, to: 2)
        #expect(original == ["a", "b", "c"])
    }

    @Test("el array original sigue siendo el mismo objeto después de llamar (no mutation)")
    func sameObject() {
        let original = ["x", "y", "z"]
        _ = original.moving(from: 0, to: 1)
        #expect(original == ["x", "y", "z"])
    }

    @Test("array de un elemento devuelve array equivalente")
    func single() { #expect(["solo"].moving(from: 0, to: 0) == ["solo"]) }

    @Test("fromIndex === toIndex no cambia el array")
    func sameIndex() { #expect(["a", "b", "c", "d"].moving(from: 2, to: 2) == ["a", "b", "c", "d"]) }

    @Test("funciona con array de objetos (logs)")
    func logs() {
        let logs = [makeLog("press_banca"), makeLog("sentadilla"), makeLog("curl_biceps")]
        let result = logs.moving(from: 0, to: 2)
        #expect(result.map(\.exerciseID) == ["sentadilla", "curl_biceps", "press_banca"])
        #expect(result[2] == logs[0])
    }

    @Test("fromIndex en límite inferior (0)")
    func fromLower() { #expect(["a", "b", "c", "d"].moving(from: 0, to: 3) == ["b", "c", "d", "a"]) }

    @Test("fromIndex en límite superior (length-1)")
    func fromUpper() { #expect(["a", "b", "c", "d"].moving(from: 3, to: 0) == ["d", "a", "b", "c"]) }

    @Test("toIndex en límite inferior (0)")
    func toLower() { #expect(["a", "b", "c"].moving(from: 2, to: 0) == ["c", "a", "b"]) }

    @Test("toIndex en límite superior (length-1)")
    func toUpper() { #expect(["a", "b", "c"].moving(from: 0, to: 2) == ["b", "c", "a"]) }

    @Test("array vacío devuelve array vacío (edge case)")
    func empty() { #expect([String]().moving(from: 0, to: 0) == []) }

    @Test("array de dos elementos, swap")
    func twoSwap() { #expect(["a", "b"].moving(from: 0, to: 1) == ["b", "a"]) }

    @Test("array de dos elementos, swap inverso")
    func twoSwapBack() { #expect(["a", "b"].moving(from: 1, to: 0) == ["b", "a"]) }

    @Test("mueve elemento del medio al principio")
    func middleToStart() { #expect(["a", "b", "c", "d"].moving(from: 2, to: 0) == ["c", "a", "b", "d"]) }

    @Test("mueve elemento del medio al final")
    func middleToEnd() { #expect(["a", "b", "c", "d"].moving(from: 1, to: 3) == ["a", "c", "d", "b"]) }

    @Test("devuelve un array nuevo (no el mismo objeto)")
    func newArray() {
        var original = ["a", "b", "c"]
        let result = original.moving(from: 0, to: 1)
        original[0] = "cambiado"
        #expect(result == ["b", "a", "c"])
    }
}
