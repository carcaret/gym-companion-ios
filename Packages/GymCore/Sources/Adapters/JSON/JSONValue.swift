import Foundation

/// Un valor JSON que conserva el orden de las claves al escribirlo, para que el `db.json` que
/// sube la app salga con el mismo formato que el de la PWA (`JSON.stringify(db, null, 2)`) y los
/// commits de GitHub solo muestren lo que cambia.
///
/// Dos objetos son iguales si tienen las mismas claves con los mismos valores, en cualquier orden
/// (como `toEqual` en los tests de la PWA).
public enum JSONValue: Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    /// En orden; sin claves repetidas.
    case object([(key: String, value: JSONValue)])

    /// El valor de una clave, si es un objeto y la tiene.
    public subscript(key: String) -> JSONValue? {
        guard case .object(let members) = self else { return nil }
        return members.first { $0.key == key }?.value
    }
}

// MARK: - Lectura

extension JSONValue: Decodable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else {
            let object = try container.decode([String: JSONValue].self)
            self = .object(object.keys.sorted().map { ($0, object[$0]!) })
        }
    }

    /// `nil` si no es JSON válido: nunca lanza ni se cae (lo que llega de fuera puede ser
    /// cualquier cosa). Las claves de los objetos quedan por orden alfabético.
    public init?(parsing data: Data) {
        guard let value = try? JSONDecoder().decode(JSONValue.self, from: data) else { return nil }
        self = value
    }

    /// Ídem con un texto; `nil` si no hay texto.
    public init?(parsing text: String?) {
        guard let text, !text.isEmpty else { return nil }
        self.init(parsing: Data(text.utf8))
    }
}

// MARK: - Escritura

extension JSONValue {
    /// Como `JSON.stringify(valor, null, indent)`; sin `indent`, todo en una línea.
    public func stringified(indent: Int? = 2) -> String {
        var output = ""
        write(to: &output, indent: indent, level: 0)
        return output
    }

    private func write(to output: inout String, indent: Int?, level: Int) {
        switch self {
        case .null: output += "null"
        case .bool(let bool): output += bool ? "true" : "false"
        case .number(let number): output += Self.format(number)
        case .string(let string): Self.writeString(string, to: &output)
        case .array(let items):
            writeContainer(open: "[", close: "]", count: items.count, to: &output, indent: indent, level: level) { index, output in
                items[index].write(to: &output, indent: indent, level: level + 1)
            }
        case .object(let members):
            writeContainer(open: "{", close: "}", count: members.count, to: &output, indent: indent, level: level) { index, output in
                Self.writeString(members[index].key, to: &output)
                output += indent == nil ? ":" : ": "
                members[index].value.write(to: &output, indent: indent, level: level + 1)
            }
        }
    }

    private func writeContainer(open: String, close: String, count: Int, to output: inout String, indent: Int?, level: Int,
                                item: (Int, inout String) -> Void) {
        guard count > 0 else {
            output += open + close
            return
        }
        output += open
        for index in 0..<count {
            if index > 0 { output += "," }
            if let indent { output += "\n" + String(repeating: " ", count: indent * (level + 1)) }
            item(index, &output)
        }
        if let indent { output += "\n" + String(repeating: " ", count: indent * level) }
        output += close
    }

    /// Como `Number.prototype.toString` en los casos que salen en los datos: los enteros sin
    /// decimales y los demás con los mínimos para no perder precisión.
    private static func format(_ number: Double) -> String {
        guard number.isFinite else { return "null" }
        if number == number.rounded(), abs(number) < 1e15 {
            return number == 0 ? "0" : String(Int64(number))
        }
        let text = "\(number)"
        // Swift escribe "1e+21" igual que JS, pero "1e-07" donde JS escribe "1e-7".
        return text.replacingOccurrences(of: "e-0", with: "e-")
    }

    private static func writeString(_ string: String, to output: inout String) {
        output += "\""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\"": output += "\\\""
            case "\\": output += "\\\\"
            case "\n": output += "\\n"
            case "\r": output += "\\r"
            case "\t": output += "\\t"
            case "\u{08}": output += "\\b"
            case "\u{0C}": output += "\\f"
            case let control where control.value < 0x20:
                let hex = String(control.value, radix: 16)
                output += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
            default: output.unicodeScalars.append(scalar)
            }
        }
        output += "\""
    }
}

// MARK: - Igualdad y literales

extension JSONValue: Hashable {
    public static func == (lhs: JSONValue, rhs: JSONValue) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null): true
        case (.bool(let a), .bool(let b)): a == b
        case (.number(let a), .number(let b)): a == b
        case (.string(let a), .string(let b)): a == b
        case (.array(let a), .array(let b)): a == b
        case (.object(let a), .object(let b)):
            a.count == b.count && a.allSatisfy { member in b.contains { $0.key == member.key && $0.value == member.value } }
        default: false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .null: hasher.combine(0)
        case .bool(let bool): hasher.combine(bool)
        case .number(let number): hasher.combine(number)
        case .string(let string): hasher.combine(string)
        case .array(let items): hasher.combine(items)
        case .object(let members):
            for member in members.sorted(by: { $0.key < $1.key }) {
                hasher.combine(member.key)
                hasher.combine(member.value)
            }
        }
    }
}

extension JSONValue: ExpressibleByNilLiteral, ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral,
    ExpressibleByStringLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral {
    public init(nilLiteral: ()) { self = .null }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(integerLiteral value: Int) { self = .number(Double(value)) }
    public init(floatLiteral value: Double) { self = .number(value) }
    public init(stringLiteral value: String) { self = .string(value) }
    public init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
    public init(dictionaryLiteral elements: (String, JSONValue)...) { self = .object(elements.map { ($0.0, $0.1) }) }
}
