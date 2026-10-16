import Foundation
import TransitionReportKit

// Uso: transition-report --gastario gastario.csv --tarjeta pagos_con_tarjeta.csv --yappy yappy_each.csv
//      [--desde 2026-10-16] [--hasta 2026-11-06]
// Escribe el reporte en Markdown por la salida estándar.

let usage = """
    Uso: transition-report --gastario <export.csv> --tarjeta <tarjeta.csv> --yappy <yappy.csv> \\
           [--desde yyyy-MM-dd] [--hasta yyyy-MM-dd]
    """

func arguments() throws -> [String: String] {
    var values: [String: String] = [:]
    var iterator = CommandLine.arguments.dropFirst().makeIterator()
    while let flag = iterator.next() {
        guard ["--gastario", "--tarjeta", "--yappy", "--desde", "--hasta"].contains(flag), let value = iterator.next() else {
            throw ReportError.invalidArguments(usage)
        }
        values[flag] = value
    }
    for required in ["--gastario", "--tarjeta", "--yappy"] where values[required] == nil {
        throw ReportError.invalidArguments(usage)
    }
    for flag in ["--desde", "--hasta"] {
        if let day = values[flag], day.wholeMatch(of: /\d{4}-\d{2}-\d{2}/) == nil {
            throw ReportError.invalidArguments("\(flag) espera yyyy-MM-dd, recibió \"\(day)\"")
        }
    }
    return values
}

func read(_ path: String) throws -> String {
    try String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
}

do {
    let args = try arguments()
    let gastarioPath = args["--gastario"]!, cardPath = args["--tarjeta"]!, yappyPath = args["--yappy"]!
    let name = { (path: String) in URL(fileURLWithPath: path).lastPathComponent }
    let yappy = try Loader.oldYappy(read(yappyPath), file: name(yappyPath))
    let comparison = try Comparison(
        gastario: Loader.gastario(read(gastarioPath), file: name(gastarioPath)),
        oldCard: Loader.oldCard(read(cardPath), file: name(cardPath)),
        oldYappy: yappy.records, invalidOldYappy: yappy.invalid,
        from: args["--desde"], to: args["--hasta"])
    print(MarkdownReport.render(comparison), terminator: "")
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
