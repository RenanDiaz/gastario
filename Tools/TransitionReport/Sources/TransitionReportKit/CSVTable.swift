import Foundation

/// CSV con encabezado, RFC 4180: campos entre comillas opcionales, comillas duplicadas,
/// saltos de línea dentro de comillas y fin de línea LF o CRLF. Los CSVs viejos mezclan
/// filas con y sin comillas; las dos formas se leen igual.
public struct CSVTable: Sendable {
    public struct Row: Sendable {
        /// Línea del archivo donde empieza la fila (el encabezado es la 1).
        public let line: Int
        let fields: [String]
        let columns: [String: Int]

        public subscript(_ column: String) -> String {
            guard let index = columns[column], index < fields.count else { return "" }
            return fields[index].trimmingCharacters(in: .whitespaces)
        }
    }

    public let header: [String]
    public let rows: [Row]

    public init(_ text: String, file: String, requiredColumns: [String]) throws {
        let records = Self.records(in: text)
        guard let first = records.first else { throw ReportError.emptyFile(file) }
        let header = first.fields.map { $0.trimmingCharacters(in: .whitespaces) }
        let missing = requiredColumns.filter { !header.contains($0) }
        guard missing.isEmpty else { throw ReportError.missingColumns(file, missing) }

        var columns: [String: Int] = [:]
        for (index, name) in header.enumerated() where columns[name] == nil { columns[name] = index }
        self.header = header
        rows = records.dropFirst()
            .filter { !($0.fields.count == 1 && $0.fields[0].trimmingCharacters(in: .whitespaces).isEmpty) }
            .map { Row(line: $0.line, fields: $0.fields, columns: columns) }
    }

    private static func records(in text: String) -> [(line: Int, fields: [String])] {
        var records: [(line: Int, fields: [String])] = []
        var fields: [String] = []
        var field = ""
        var inQuotes = false
        var line = 1
        var recordLine = 1
        var characters = text.replacingOccurrences(of: "\u{FEFF}", with: "").makeIterator()
        var pending = characters.next()

        func endRecord() {
            fields.append(field)
            records.append((recordLine, fields))
            fields = []
            field = ""
        }

        while let character = pending {
            pending = characters.next()
            if inQuotes {
                if character == "\"" {
                    if pending == "\"" {
                        field.append("\"")
                        pending = characters.next()
                    } else {
                        inQuotes = false
                    }
                } else {
                    if character == "\n" || character == "\r\n" { line += 1 }
                    field.append(character)
                }
                continue
            }
            switch character {
            case "\"": inQuotes = true
            case ",":
                fields.append(field)
                field = ""
            case "\n", "\r\n", "\r":
                endRecord()
                line += 1
                recordLine = line
            default: field.append(character)
            }
        }
        if !field.isEmpty || !fields.isEmpty { endRecord() }
        return records
    }
}

public enum ReportError: Error, CustomStringConvertible, Equatable {
    case emptyFile(String)
    case missingColumns(String, [String])
    case invalidDate(String, line: Int, value: String)
    case invalidArguments(String)

    public var description: String {
        switch self {
        case .emptyFile(let file): "\(file): está vacío"
        case .missingColumns(let file, let columns):
            "\(file): faltan columnas \(columns.joined(separator: ", "))"
        case .invalidDate(let file, let line, let value): "\(file):\(line): fecha inválida \"\(value)\""
        case .invalidArguments(let message): message
        }
    }
}
