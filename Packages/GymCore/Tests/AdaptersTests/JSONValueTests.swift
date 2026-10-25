import Adapters
import Foundation
import Testing

// Port de tests/unit/json-parse-safety.test.js. En la PWA el patrón protegía la lectura de
// localStorage; en la app, lo que llega de GitHub: un contenido corrupto no puede tumbar la app,
// se lee como "nada" (y el adaptador lo da por contenido inválido).
@Suite("safe JSON.parse pattern")
struct SafeJSONParseTests {
    @Test("JSON válido → devuelve objeto")
    func valid() {
        #expect(JSONValue(parsing: #"{"a":1}"#) == ["a": 1])
    }

    @Test("JSON inválido → devuelve null sin excepción")
    func invalid() {
        #expect(JSONValue(parsing: "{corrupto}") == nil)
    }

    @Test("string vacío → devuelve null")
    func empty() {
        #expect(JSONValue(parsing: "") == nil)
    }

    @Test("null → devuelve null")
    func null() {
        #expect(JSONValue(parsing: String?.none) == nil)
    }

    // En Swift no hay `undefined`: lo que en JS llega sin definir (una clave que no está) aquí es
    // `nil`, igual que el caso anterior; se mantiene para conservar el test.
    @Test("undefined → devuelve null")
    func undefined() {
        let missing: [String: String] = [:]
        #expect(JSONValue(parsing: missing["gym_companion_db"]) == nil)
    }

    @Test("HTML como valor → no lanza excepción")
    func html() {
        #expect(JSONValue(parsing: "<html>") == nil)
    }

    @Test("JSON truncado → no lanza excepción")
    func truncated() {
        #expect(JSONValue(parsing: #"{"auth":{"user":"carlos""#) == nil)
    }
}

@Suite("JSON con el formato de la PWA")
struct JSONValueFormatTests {
    @Test("se escribe como JSON.stringify(db, null, 2): mismo orden de claves, sangría y números")
    func stringify() {
        let value: JSONValue = [
            "b": ["x": 1, "y": [1, 2.5, nil]],
            "a": [],
            "c": [:],
            "d": ["texto \"con\" comillas\\barra\n y tilde: España / ñ", true, false],
        ]
        // Lo que da `JSON.stringify` en Node con esos datos.
        #expect(value.stringified() == """
        {
          "b": {
            "x": 1,
            "y": [
              1,
              2.5,
              null
            ]
          },
          "a": [],
          "c": {},
          "d": [
            "texto \\"con\\" comillas\\\\barra\\n y tilde: España / ñ",
            true,
            false
          ]
        }
        """)
    }

    @Test("los números enteros van sin decimales y los demás con los mínimos")
    func numbers() {
        #expect(JSONValue.array([104, 6.8, 18.1, 0, -2, 52.5, 1e21]).stringified(indent: nil) == "[104,6.8,18.1,0,-2,52.5,1e+21]")
    }

    @Test("los caracteres de control se escapan como en JS")
    func controlCharacters() {
        #expect(JSONValue.string("a\u{01}\t\u{08}\u{0C}\r").stringified() == #""a\u0001\t\b\f\r""#)
    }

    @Test("dos objetos con las mismas claves en otro orden son iguales")
    func objectEquality() {
        let a: JSONValue = ["x": 1, "y": 2]
        let b: JSONValue = ["y": 2, "x": 1]
        #expect(a == b)
        #expect(Set([a, b]).count == 1)
        #expect(a != ["x": 1])
    }

    @Test("leer lo escrito devuelve lo mismo")
    func roundTrip() {
        let value: JSONValue = ["a": [1, "dos", nil, true, ["b": 2.5]]]
        #expect(JSONValue(parsing: value.stringified()) == value)
    }
}
