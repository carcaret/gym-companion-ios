/// JSON con las claves en el orden en que se dan, escrito como `JSON.stringify(valor, null, 2)`
/// de JavaScript. `JSONEncoder` no conserva el orden de las claves, y la PWA y la app escriben el
/// mismo `db.json` en git: con el mismo orden y la misma sangría, un cambio no reescribe el
/// fichero entero. (La PWA no siempre usa el mismo orden en las sesiones antiguas: la primera
/// subida desde la app lo normaliza una vez.)
enum OrderedJSON {
    case object([(String, OrderedJSON)])
    case array([OrderedJSON])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    var text: String {
        var out = ""
        write(to: &out, indent: 0)
        return out
    }

    private func write(to out: inout String, indent: Int) {
        let inner = String(repeating: " ", count: indent + 2)
        let closing = String(repeating: " ", count: indent)
        switch self {
        case .object(let members):
            guard !members.isEmpty else { out += "{}"; return }
            out += "{\n"
            for (index, (key, value)) in members.enumerated() {
                out += inner + Self.quoted(key) + ": "
                value.write(to: &out, indent: indent + 2)
                out += index < members.count - 1 ? ",\n" : "\n"
            }
            out += closing + "}"
        case .array(let items):
            guard !items.isEmpty else { out += "[]"; return }
            out += "[\n"
            for (index, item) in items.enumerated() {
                out += inner
                item.write(to: &out, indent: indent + 2)
                out += index < items.count - 1 ? ",\n" : "\n"
            }
            out += closing + "]"
        case .string(let value):
            out += Self.quoted(value)
        case .number(let value):
            // Como JS: los enteros sin ".0" y el resto con su representación más corta (18.1).
            out += value.rounded() == value && abs(value) < 1e15 ? String(Int(value)) : String(value)
        case .bool(let value):
            out += value ? "true" : "false"
        case .null:
            out += "null"
        }
    }

    private static func quoted(_ text: String) -> String {
        var out = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            case _ where scalar.value < 0x20:
                let hex = String(scalar.value, radix: 16)
                out += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
            default: out.unicodeScalars.append(scalar)
            }
        }
        return out + "\""
    }
}
