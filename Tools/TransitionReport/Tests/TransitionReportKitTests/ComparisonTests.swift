import Foundation
import Testing
@testable import TransitionReportKit

// Datos inventados con el formato real de los tres archivos: el `Text` de los atajos viejos
// (filas con y sin comillas) y el export de Gastario (ISO 8601 con offset, CRLF).

private let oldCard = """
    fecha,comercio,monto,tarjeta,ciudad,lat,lon
    2026-10-08 07:09,Carniceria Ejemplo,$3.50,Debito,,,
    2026-10-08 13:17,"Tienda Uno","$14.61","Debito","David","8.44","-82.43"
    2026-10-09 08:30,"Cafe Ejemplo","$6.90","Debito","David","8.43","-82.42"
    2026-10-09 15:21,"Hotel Ejemplo","$1,123.20","Debito","","",""

    """

private let oldYappy = """
    fecha,tipo,monto,contraparte,mensaje,confirmacion,fechaYappy
    2026-10-08 08:04,"Enviaste","0.01","Ana Prueba","sin signo","AAAAA-00000001","08 oct 2026 08:04 a. m."
    2026-10-08 21:15,"Te enviaron","100.00","Ana Prueba","","BBBBB-00000002","08 oct 2026 09:13 p. m."
    2026-10-08 21:16,"Te enviaron","100.00","Ana Prueba","","BBBBB-00000002","08 oct 2026 09:13 p. m."
    2026-10-09 00:05,"Pagaste","-49.06","SEGUROS EJEMPLO","Por pedido 1","CCCCC-00000003","08 oct 2026 11:58 p. m."
    2026-10-09 21:41,"","-","","","",""
    2026-10-09 21:42,"","-24.21","","Pedido","","09 oct 2026 09:29 p. m."
    2026-10-09 22:00,"Enviaste","-4.00","Luis Prueba","","DDDDD-00000004","09 oct 2026 09:59 p. m."

    """

private let header =
    "occurredAt,capturedAt,source,direction,amount,counterparty,cardName,yappyMessage,confirmation,city,latitude,longitude,note,parseStatus,attachmentCount"

private func gastario(_ rows: [String]) -> String {
    ([header] + rows).joined(separator: "\r\n") + "\r\n"
}

private let fullGastario = gastario([
    "2026-10-08T07:09:41-05:00,2026-10-08T07:09:41-05:00,card,outflow,-3.50,Carniceria Ejemplo,Debito,,,,,,,ok,0",
    "2026-10-08T13:17:58-05:00,2026-10-08T13:17:58-05:00,card,outflow,-14.61,Tienda Uno,Debito,,,David,8.44,-82.43,,ok,0",
    "2026-10-09T08:31:02-05:00,2026-10-09T08:31:02-05:00,card,outflow,-6.90,Cafe Ejemplo,Debito,,,David,8.43,-82.42,,ok,0",
    "2026-10-09T15:21:10-05:00,2026-10-09T15:21:10-05:00,card,outflow,-1123.20,Hotel Ejemplo,Debito,,,,,,\"nota, con coma\",ok,0",
    "2026-10-08T08:04:00-05:00,2026-10-08T08:04:30-05:00,yappy,outflow,-0.01,Ana Prueba,,sin signo,AAAAA-00000001,,,,,ok,0",
    "2026-10-08T21:13:00-05:00,2026-10-08T21:15:30-05:00,yappy,inflow,100.00,Ana Prueba,,,BBBBB-00000002,,,,,ok,0",
    "2026-10-08T23:58:00-05:00,2026-10-09T00:05:10-05:00,yappy,outflow,-49.06,SEGUROS EJEMPLO,,Por pedido 1,CCCCC-00000003,,,,,ok,0",
    "2026-10-09T21:59:00-05:00,2026-10-09T22:00:20-05:00,yappy,outflow,-4.00,Luis Prueba,,,DDDDD-00000004,,,,,ok,0",
    "2026-10-09T21:29:00-05:00,2026-10-09T21:42:10-05:00,yappy,outflow,-24.21,Ana Prueba,,Pedido,FFFFF-00000006,,,,,ok,0",
    "2026-10-09T12:00:00-05:00,2026-10-09T12:00:00-05:00,manual,outflow,-20.00,Efectivo,,,,,,,,ok,0",
])

private func compare(_ gastarioCSV: String, from: String? = nil, to: String? = nil) throws -> Comparison {
    let yappy = try Loader.oldYappy(oldYappy)
    return try Comparison(
        gastario: Loader.gastario(gastarioCSV), oldCard: Loader.oldCard(oldCard),
        oldYappy: yappy.records, invalidOldYappy: yappy.invalid, from: from, to: to)
}

struct LoaderTests {
    @Test func csvViejoDeTarjetaConYSinComillas() throws {
        let records = try Loader.oldCard(oldCard)
        #expect(records.map(\.amount) == [-3.5, -14.61, -6.9, -1123.2].map { Decimal($0) })
        #expect(records.map(\.counterparty) == ["Carniceria Ejemplo", "Tienda Uno", "Cafe Ejemplo", "Hotel Ejemplo"])
        #expect(records[0].day == "2026-10-08")
        #expect(records[0].origin == "tarjeta:2")
    }

    @Test func elSignoDeYappySaleDelTipo() throws {
        let (records, invalid) = try Loader.oldYappy(oldYappy)
        // "Enviaste" sin `-` en el CSV viejo: igual es salida.
        #expect(records[0].amount == Decimal(string: "-0.01"))
        #expect(records[1].amount == 100)
        #expect(invalid.map(\.origin) == ["yappy:6"])
        #expect(invalid[0].summary == "2026-10-09 21:41 · -")
    }

    /// Un Yappy que el atajo viejo leyó a medias: sin tipo ni confirmación, con monto.
    @Test func yappyLeidoAMediasCuenta() throws {
        let (records, _) = try Loader.oldYappy(oldYappy)
        let partial = try #require(records.first { $0.origin == "yappy:7" })
        #expect(partial.amount == Decimal(string: "-24.21"))
        #expect(partial.confirmation == nil)
        #expect(partial.day == "2026-10-09")
    }

    @Test func elDiaDeYappyEsElDelCorreo() throws {
        let (records, _) = try Loader.oldYappy(oldYappy)
        // El atajo corrió el 9 a las 00:05, pero el Yappy es del 8 a las 11:58 p. m.
        #expect(records[3].day == "2026-10-08")
    }

    @Test func gastarioIgnoraManualesYLeeComillas() throws {
        let records = try Loader.gastario(fullGastario)
        #expect(records.count == 9)
        #expect(!records.contains { $0.counterparty == "Efectivo" })
        #expect(records[3].amount == Decimal(string: "-1123.20"))
    }

    @Test func columnaFaltanteEsError() {
        #expect(throws: ReportError.missingColumns("tarjeta", ["monto"])) {
            try Loader.oldCard("fecha,comercio\n2026-10-08 07:09,X\n")
        }
    }

    @Test func fechaInvalidaDiceLaLinea() {
        #expect(throws: ReportError.invalidDate("tarjeta", line: 2, value: "ayer")) {
            try Loader.oldCard("fecha,comercio,monto\nayer,X,$1.00\n")
        }
    }
}

struct ComparisonTests {
    @Test func todoCuadra() throws {
        let comparison = try compare(fullGastario)
        #expect(comparison.from == "2026-10-08")
        #expect(comparison.to == "2026-10-09")
        #expect(comparison.days.filter { !$0.matches }.isEmpty)
        // La repetida del CSV viejo no cuenta como captura, pero se lista.
        #expect(comparison.discrepancies.map(\.kind) == [.duplicateOld])
        #expect(comparison.invalidOldRows.count == 1)
    }

    @Test func diaConTotales() throws {
        let day = try #require(try compare(fullGastario).days.first { $0.day == "2026-10-08" })
        #expect(day.old[.card] == Comparison.DayTotals(count: 2, sum: Decimal(string: "-18.11")!))
        #expect(day.old[.yappy] == Comparison.DayTotals(count: 3, sum: Decimal(string: "50.93")!))
        #expect(day.gastario[.yappy] == day.old[.yappy])
    }

    @Test func tarjetaPerdidaEnGastario() throws {
        var rows = fullGastario.components(separatedBy: "\r\n")
        rows.removeAll { $0.contains("Hotel Ejemplo") }
        let comparison = try compare(rows.joined(separator: "\r\n"))
        let lost = try #require(comparison.discrepancies.first { $0.kind == .onlyOld })
        #expect(lost.record.counterparty == "Hotel Ejemplo")
        #expect(lost.hint.hasPrefix("(c)"))
        #expect(comparison.days.first { $0.day == "2026-10-09" }?.matches == false)
    }

    @Test func yappySoloEnGastarioYFailed() throws {
        let csv = fullGastario + [
            "2026-10-09T23:00:00-05:00,2026-10-09T23:00:10-05:00,yappy,inflow,7.00,Ana Prueba,,,EEEEE-00000005,,,,,ok,0",
            "2026-10-09T21:41:30-05:00,2026-10-09T21:41:30-05:00,yappy,inflow,0.00,,,,,,,,,failed,0",
        ].joined(separator: "\r\n") + "\r\n"
        let kinds = try compare(csv).discrepancies.filter { $0.kind == .onlyGastario }
        #expect(kinds.count == 2)
        #expect(kinds.contains { $0.hint.hasPrefix("(d)") && $0.record.confirmation == "EEEEE-00000005" })
        #expect(kinds.contains { $0.hint.contains("failed") })
    }

    @Test func tarjetaSinMontoEnGastario() throws {
        let csv = fullGastario.replacingOccurrences(of: "card,outflow,-6.90", with: "card,outflow,0.00")
        let item = try #require(try compare(csv).discrepancies.first { $0.kind == .amountDiffers })
        #expect(item.other?.amount == 0)
        #expect(item.hint.contains("partial"))
    }

    @Test func tarjetaFueraDeLaVentanaDeTiempo() throws {
        // Mismo monto, pero 10 minutos después: no es la misma compra.
        let csv = fullGastario.replacingOccurrences(of: "2026-10-09T08:31:02", with: "2026-10-09T08:41:02")
        let kinds = try compare(csv).discrepancies.map(\.kind)
        #expect(kinds.contains(.onlyOld))
        #expect(kinds.contains(.onlyGastario))
    }

    @Test func rangoDeDias() throws {
        let comparison = try compare(fullGastario, from: "2026-10-09", to: "2026-10-09")
        #expect(comparison.days.map(\.day) == ["2026-10-09"])
        #expect(comparison.invalidOldRows.count == 1)
        #expect(comparison.discrepancies.isEmpty)
    }

    @Test func exportVacioPideRango() {
        #expect(throws: ReportError.self) { try compare(gastario([])) }
    }
}

struct MarkdownReportTests {
    @Test func montos() {
        #expect(MarkdownReport.money(Decimal(string: "-1123.2")!) == "-1123.20")
        #expect(MarkdownReport.money(0) == "0.00")
        #expect(MarkdownReport.money(Decimal(string: "0.005")!) == "0.01")
        #expect(MarkdownReport.money(Decimal(string: "47.75")!) == "47.75")
    }

    @Test func tablaPorDia() throws {
        let text = MarkdownReport.render(try compare(fullGastario))
        #expect(text.contains("| 2026-10-08 | 2 · -18.11 | 2 · -18.11 | 3 · 50.93 | 3 · 50.93 | ✅ |"))
        #expect(text.contains("Repetida en el CSV viejo"))
        #expect(text.contains("- `yappy:6`: 2026-10-09 21:41 · -"))
    }
}
