import Foundation
import SwiftData
import Testing
@testable import GastarioCore

/// Bitácora de captura (SPEC Fase 7a).
@MainActor
struct CaptureLogTests {
    private let panama = TimeZone(identifier: "America/Panama")!

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "CaptureLogTests-\(UUID().uuidString)")
    }

    private func date(_ text: String) -> Date {
        ISO8601DateFormatter().date(from: text)!
    }

    private func makeLog(at directory: URL, now: Date = .now) -> CaptureLog {
        CaptureLog(directory: directory, version: "0.1.0", build: "1", now: { now })
    }

    @Test func cadaEventoEsUnaLineaJSONYProcessVaUnaVez() throws {
        let directory = temporaryDirectory()
        let log = makeLog(at: directory)
        let inv = UUID()
        log.record(.receivedCard(inv, inputs: CardParams(
            merchant: "M/S Betty", amount: "$3.10", cardName: "Debito Platinum",
            city: "David", latitude: 8.43, longitude: -82.41)))
        log.record(.rawSaved(inv, movementID: UUID()))
        log.record(.done(inv))

        let lines = log.lines()
        #expect(lines.count == 4)
        for line in lines {
            #expect(try JSONSerialization.jsonObject(with: Data(line.utf8)) is [String: Any])
        }
        let summary = CaptureLogReader.summarize(lines)
        #expect(summary.unreadableLines == 0)
        #expect(lines.filter { $0.contains("\"ev\":\"process\"") }.count == 1)
        #expect(summary.invocations.map(\.stage) == [.done])
    }

    @Test func elArchivoDelMesSigueAPanama() {
        // 31/10 23:30 en Panamá es 1/11 04:30 en UTC.
        let directory = temporaryDirectory()
        let log = makeLog(at: directory, now: date("2026-11-01T04:30:00Z"))
        log.record(.done(UUID()))
        #expect(log.files().map(\.lastPathComponent) == ["capture-2026-10.jsonl"])
    }

    @Test func unaRutaSinPermisoNoLanza() throws {
        // Un archivo donde debería ir el directorio: `createDirectory` falla.
        let blocker = temporaryDirectory()
        try Data("x".utf8).write(to: blocker)
        let log = makeLog(at: blocker)
        log.record(.done(UUID()))
        #expect(log.lines().isEmpty)
    }

    @Test func conservaNilDistintoDeVacio() throws {
        let directory = temporaryDirectory()
        let log = makeLog(at: directory)
        log.record(.receivedCard(UUID(), inputs: CardParams(
            merchant: nil, amount: "", cardName: nil, city: "David", latitude: nil, longitude: nil)))

        let line = try #require(log.lines().last)
        #expect(line.contains("\"merchant\":null"))
        #expect(line.contains("\"amount\":\"\""))
        let inputs = try #require(CaptureLogReader.summarize(log.lines()).invocations.first?.received?.inputs)
        #expect(inputs.merchant == nil)
        #expect(inputs.amount == "")
    }

    @Test func retencionDejaTresMesesYNoTocaOtrosArchivos() throws {
        let directory = temporaryDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for name in ["capture-2026-07.jsonl", "capture-2026-08.jsonl", "capture-2026-09.jsonl",
                     "capture-2026-10.jsonl", "otro.txt", "capture-viejo.jsonl"] {
            try Data().write(to: directory.appending(path: name))
        }
        makeLog(at: directory, now: date("2026-10-30T12:00:00-05:00")).prune()

        let remaining = try FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false)).sorted()
        #expect(remaining == [
            "capture-2026-08.jsonl", "capture-2026-09.jsonl", "capture-2026-10.jsonl",
            "capture-viejo.jsonl", "otro.txt",
        ])
    }

    // MARK: - Observador en CaptureService

    @MainActor
    final class SpyObserver: CaptureObserver {
        enum Call: Equatable {
            case rawSaved(UUID)
            case saved(UUID, CaptureOutcome)
        }
        private(set) var calls: [Call] = []
        func rawSaved(movementID: UUID) { calls.append(.rawSaved(movementID)) }
        func saved(movementID: UUID, outcome: CaptureOutcome, status: ParseStatus, issues: Set<ParseIssue>) {
            calls.append(.saved(movementID, outcome))
        }
    }

    @Test func tarjetaAvisaRawSavedAntesQueSavedConElMismoID() async throws {
        let observer = SpyObserver()
        let service = CaptureService(container: GastarioStore.makeContainer(inMemory: true), observer: observer)
        let outcome = try await service.captureCard(CardRawInputs(merchant: "M/S Betty", amount: "$3.10", cardName: "Debito"))

        guard case .created(let id) = outcome else { Issue.record("Esperaba created"); return }
        #expect(observer.calls == [.rawSaved(id), .saved(id, .created(id))])
    }

    @Test func yappyDuplicadoAvisaSavedConElExistente() async throws {
        let container = GastarioStore.makeContainer(inMemory: true)
        let first = try await CaptureService(container: container).captureYappy(content: YappyBodies.sent())
        guard case .created(let original) = first else { Issue.record("Esperaba created"); return }

        let observer = SpyObserver()
        _ = try await CaptureService(container: container, observer: observer).captureYappy(content: YappyBodies.sent())

        guard case .rawSaved(let newID) = observer.calls.first else { Issue.record("Esperaba rawSaved"); return }
        #expect(observer.calls == [.rawSaved(newID), .saved(newID, .duplicate(existing: original))])
    }

    // MARK: - Interpretación

    private func event(_ base: CaptureLogEvent, at seconds: TimeInterval, pid: Int32 = 1) -> CaptureLogEvent {
        var event = base
        event.t = date("2026-10-22T18:02:00-05:00").addingTimeInterval(seconds)
        event.pid = pid
        return event
    }

    private func lines(_ events: [CaptureLogEvent]) throws -> [String] {
        let encoder = CaptureLogCoding.encoder()
        return try events.map { String(decoding: try encoder.encode($0), as: UTF8.self) }
    }

    private func received(_ inv: UUID) -> CaptureLogEvent {
        .receivedCard(inv, inputs: CardParams(
            merchant: "M/S Betty", amount: "$3.10", cardName: nil, city: nil, latitude: nil, longitude: nil))
    }

    @Test func clasificaCadaEtapa() throws {
        let movement = UUID()
        let saved = CaptureLogEvent.saved(UUID(), movementID: movement, outcome: .created(movement), status: .ok, issues: [])
        struct StoreDown: Error {}
        let cases: [(String, [(UUID) -> CaptureLogEvent], CaptureStage)] = [
            ("received", [{ self.received($0) }], .received),
            ("error", [{ self.received($0) }, { .error($0, StoreDown()) }], .error),
            ("rawSaved", [{ self.received($0) }, { .rawSaved($0, movementID: movement) }], .rawSaved),
            ("saved", [{ self.received($0) }, { .rawSaved($0, movementID: movement) }, { var e = saved; e.inv = $0; return e }], .saved),
            ("done", [{ self.received($0) }, { .rawSaved($0, movementID: movement) }, { var e = saved; e.inv = $0; return e }, { .done($0) }], .done),
            ("sin received", [{ .rawSaved($0, movementID: movement) }], .unknown),
        ]
        for (name, builders, expected) in cases {
            let inv = UUID()
            let events = builders.enumerated().map { event($0.element(inv), at: TimeInterval($0.offset)) }
            let summary = CaptureLogReader.summarize(try lines(events))
            #expect(summary.invocations.map(\.stage) == [expected], "\(name)")
        }
    }

    @Test func sinInvocacionCercaDeLaHoraDelPago() throws {
        let summary = CaptureLogReader.summarize(try lines([event(received(UUID()), at: 0)]))
        let payment = date("2026-10-22T19:30:00-05:00")
        #expect(summary.invocations(from: payment.addingTimeInterval(-300), to: payment.addingTimeInterval(300)).isEmpty)
        #expect(summary.invocations(from: payment.addingTimeInterval(-7200), to: payment).count == 1)
    }

    @Test func distingueBorradoAMano() throws {
        let inv = UUID()
        let borrado = UUID()
        let perdido = UUID()
        var deletion = CaptureLogEvent(ev: .deleted)
        deletion.movementID = borrado
        deletion.from = .list
        let summary = CaptureLogReader.summarize(try lines([
            event(received(inv), at: 0), event(.rawSaved(inv, movementID: borrado), at: 1),
            event(.done(inv), at: 2), event(deletion, at: 60),
        ]))
        let invocation = try #require(summary.invocations.first)
        #expect(invocation.movementID == borrado)
        #expect(summary.deletion(of: borrado)?.from == .list)
        #expect(summary.deletion(of: perdido) == nil)
    }

    @Test func detectaCambioDePid() throws {
        let inv = UUID()
        let summary = CaptureLogReader.summarize(try lines([
            event(received(inv), at: 0, pid: 10), event(.done(inv), at: 1, pid: 11),
        ]))
        #expect(summary.invocations.first?.pidChanged == true)
    }

    @Test func unaLineaCorruptaSeSaltaSinPerderLasDemas() throws {
        let inv = UUID()
        var all = try lines([event(received(inv), at: 0), event(.done(inv), at: 1)])
        all.insert("{\"ev\":\"done\",\"t\":", at: 1)
        let summary = CaptureLogReader.summarize(all)
        #expect(summary.unreadableLines == 1)
        #expect(summary.invocations.map(\.stage) == [.done])
    }
}
