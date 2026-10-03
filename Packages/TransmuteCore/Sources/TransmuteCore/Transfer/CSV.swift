import Foundation

/// Writing CSV as RFC 4180 has it: comma-separated, CRLF line ends, and a field quoted when it
/// holds a comma, a quote or a line break, with quotes inside doubled.
enum CSV {
    static func field(_ text: String) -> String {
        guard text.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return text }
        return "\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    static func line(_ fields: [String]) -> String {
        fields.map(field).joined(separator: ",") + "\r\n"
    }

    /// Splits text into rows of fields. Reads commas or semicolons (Strong uses semicolons in
    /// some regions), quoted fields with line breaks in them, and any line ending.
    static func rows(_ text: String) -> [[String]] {
        let text = text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        let delimiter = delimiter(of: text)
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isQuoted = false
        var characters = text.makeIterator()
        var pending = characters.next()
        while let character = pending {
            pending = characters.next()
            if isQuoted {
                if character != "\"" {
                    field.append(character)
                } else if pending == "\"" {
                    field.append("\"")
                    pending = characters.next()
                } else {
                    isQuoted = false
                }
            } else if character == "\"" {
                isQuoted = true
            } else if character == delimiter {
                row.append(field)
                field = ""
            } else if character.isNewline {
                row.append(field)
                field = ""
                rows.append(row)
                row = []
            } else {
                field.append(character)
            }
        }
        if !field.isEmpty || !row.isEmpty {
            rows.append(row + [field])
        }
        // Blank lines carry nothing.
        return rows.filter { $0 != [""] }
    }

    /// Whichever of comma and semicolon the first line has more of.
    private static func delimiter(of text: String) -> Character {
        let header = text.prefix { !$0.isNewline }
        return header.count { $0 == ";" } > header.count { $0 == "," } ? ";" : ","
    }
}

/// A parsed CSV file: a header row and the rows under it, read by column name.
struct CSVTable {
    /// Header names, lowercased and trimmed.
    let headers: [String]
    let rows: [[String]]

    /// `nil` when there's no header row.
    init?(_ text: String) {
        let all = CSV.rows(text)
        guard let header = all.first else { return nil }
        headers = header.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        rows = Array(all.dropFirst())
    }

    func has(_ names: String...) -> Bool {
        names.allSatisfy(headers.contains)
    }

    /// The first column with one of these names.
    func column(_ names: String...) -> Int? {
        names.lazy.compactMap(headers.firstIndex(of:)).first
    }

    /// A column named `name`, or `name (unit)` as in "weight (kg)", with the unit if it has one.
    func column(measuring name: String) -> (index: Int, unit: String?)? {
        if let index = headers.firstIndex(of: name) { return (index, nil) }
        guard let index = headers.firstIndex(where: { $0.hasPrefix("\(name) (") && $0.hasSuffix(")") }) else {
            return nil
        }
        return (index, String(headers[index].dropFirst(name.count + 2).dropLast()))
    }

    /// The trimmed text at a column, empty when the row is short or the column is missing.
    static func text(_ row: [String], _ column: Int?) -> String {
        guard let column, row.indices.contains(column) else { return "" }
        return row[column].trimmingCharacters(in: .whitespaces)
    }

    /// A number at a column. Reads a decimal comma too.
    static func number(_ row: [String], _ column: Int?) -> Double? {
        Double(text(row, column).replacingOccurrences(of: ",", with: "."))
    }
}
