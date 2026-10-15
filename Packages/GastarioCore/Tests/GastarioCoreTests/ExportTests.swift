import Foundation
import Testing
@testable import GastarioCore

struct CSVExporterTests {
    let iso = ISO8601DateFormatter()

    /// Golden: uno con coma y comillas en la nota, uno `inflow`, uno sin ubicación (SPEC Fase 5).
    @Test func golden() {
        let rows = [
            CSVRow(
                occurredAt: iso.date(from: "2026-10-07T12:30:00-05:00")!,
                capturedAt: iso.date(from: "2026-10-07T12:30:41-05:00")!,
                source: "yappy", direction: .inflow, amount: Decimal(string: "1250")!,
                counterparty: "Luis Herrera", yappyMessage: "Devolucion", confirmation: "BVNHE-38291047",
                note: "Préstamo", parseStatus: "ok"),
            CSVRow(
                occurredAt: iso.date(from: "2026-10-04T08:31:00-05:00")!,
                capturedAt: iso.date(from: "2026-10-04T08:31:05-05:00")!,
                source: "card", direction: .outflow, amount: Decimal(string: "3.8")!,
                counterparty: "SUPER 99", cardName: "Visa", city: "Panamá", latitude: 8.98, longitude: -79.52,
                note: "Pan, leche y \"queso\"\npara la semana", parseStatus: "ok", attachmentCount: 2),
            CSVRow(
                occurredAt: iso.date(from: "2026-10-05T19:00:00-05:00")!,
                capturedAt: iso.date(from: "2026-10-05T19:00:00-05:00")!,
                source: "manual", direction: .outflow, amount: Decimal(string: "12.50")!,
                counterparty: "Taxi", parseStatus: "ok"),
        ]

        let expected = [
            "occurredAt,capturedAt,source,direction,amount,counterparty,cardName,yappyMessage,confirmation,city,latitude,longitude,note,parseStatus,attachmentCount",
            "2026-10-04T08:31:00-05:00,2026-10-04T08:31:05-05:00,card,outflow,-3.80,SUPER 99,Visa,,,Panamá,8.98,-79.52,\"Pan, leche y \"\"queso\"\"\npara la semana\",ok,2",
            "2026-10-05T19:00:00-05:00,2026-10-05T19:00:00-05:00,manual,outflow,-12.50,Taxi,,,,,,,,ok,0",
            "2026-10-07T12:30:00-05:00,2026-10-07T12:30:41-05:00,yappy,inflow,1250.00,Luis Herrera,,Devolucion,BVNHE-38291047,,,,Préstamo,ok,0",
        ].joined(separator: "\r\n") + "\r\n"

        #expect(CSVExporter.csv(rows) == expected)
    }

    @Test func sinBOM() {
        let data = CSVExporter.export([])
        #expect(!data.starts(with: [0xEF, 0xBB, 0xBF]))
        #expect(String(decoding: data, as: UTF8.self).hasPrefix("occurredAt,"))
    }
}

struct BackupPolicyTests {
    let last = ISO8601DateFormatter().date(from: "2026-10-01T09:00:00-05:00")!

    @Test func bordes() {
        let day: TimeInterval = 24 * 60 * 60
        #expect(!BackupPolicy.isDue(lastExportAt: last, now: last.addingTimeInterval(6 * day + 23 * 3600)))
        #expect(BackupPolicy.isDue(lastExportAt: last, now: last.addingTimeInterval(7 * day)))
        #expect(BackupPolicy.isDue(lastExportAt: nil, now: last))
    }

    /// C5, en hora de Panamá.
    @Test func nombreDeArchivo() {
        let date = ISO8601DateFormatter().date(from: "2026-10-15T02:05:00Z")!
        #expect(BackupPolicy.fileName(for: date) == "Gastario-2026-10-14-2105.csv")
    }

    @Test func estadoEnUserDefaults() throws {
        let suite = "gastario.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = BackupState(defaults: defaults)

        #expect(state.isDue(now: last))
        state.recordFailure("iCloud Drive no disponible", at: last)
        #expect(state.lastExportError == "iCloud Drive no disponible")
        #expect(state.lastExportAt == nil)
        #expect(state.isDue(now: last))

        state.recordSuccess(at: last)
        #expect(state.lastExportAt == last)
        #expect(state.lastExportError == nil)
        #expect(!state.isDue(now: last.addingTimeInterval(60)))
    }
}
