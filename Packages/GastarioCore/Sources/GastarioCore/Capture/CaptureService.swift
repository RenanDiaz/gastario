import Foundation
import GastarioParsing
import OSLog
import SwiftData

/// Pipeline de captura de los App Intents (SPEC Fase 2). Orden obligatorio (`INTENT.md`):
/// 1. guardar el crudo; 2. parsear; 3. actualizar campos y estado; 4. guardar;
/// 5. notificar; 6. respaldo si corresponde.
///
/// La deduplicación de Yappy se hace **después** de guardar el crudo y parsear: necesita la
/// confirmación, que sale del parser, y un parser que falle antes de guardar perdería la
/// captura (principio 2). Si resulta duplicado, se borra el recién insertado.
///
/// `@MainActor`: las capturas del proceso se serializan, así dos correos iguales que llegan
/// juntos no pasan los dos la deduplicación.
@MainActor
public final class CaptureService {
    private let container: ModelContainer
    private let parser: any CaptureParser
    private let notifier: any MovementNotifier
    private let backup: any BackupTrigger
    private let observer: any CaptureObserver
    private let logger = Logger(subsystem: "com.renandiaz.Gastario", category: "capture")

    public init(
        container: ModelContainer,
        parser: any CaptureParser = DefaultCaptureParser(),
        notifier: any MovementNotifier = NoopNotifier(),
        backup: any BackupTrigger = NoopBackupTrigger(),
        observer: any CaptureObserver = NoopCaptureObserver()
    ) {
        self.container = container
        self.parser = parser
        self.notifier = notifier
        self.backup = backup
        self.observer = observer
    }

    /// Solo lanza si el store no responde; un fallo de parseo se guarda como `partial`/`failed`.
    public func captureCard(_ inputs: CardRawInputs, capturedAt: Date = .now) async throws -> CaptureOutcome {
        let context = ModelContext(container)

        // 1. Crudo, con estado provisional `failed` por si lo que sigue falla.
        let movement = Movement(
            source: .card, direction: .outflow, amount: 0, occurredAt: capturedAt, capturedAt: capturedAt,
            parseStatus: .failed, parseIssues: [.amount, .counterparty])
        movement.rawInputs = Self.json(inputs)
        context.insert(movement)
        try context.save()
        observer.rawSaved(movementID: movement.id)

        // 2–3.
        do {
            ParseApplier.apply(try parser.parseCard(inputs), to: movement)
        } catch {
            logger.error("Parseo de tarjeta falló, queda failed: \(error.localizedDescription, privacy: .public)")
        }

        // 4.
        try context.save()
        observer.saved(
            movementID: movement.id, outcome: .created(movement.id),
            status: movement.parseStatus, issues: movement.parseIssues)

        await finish(movement.id)
        return .created(movement.id)
    }

    /// Solo lanza si el store no responde; un fallo de parseo se guarda como `partial`/`failed`.
    public func captureYappy(content: String, capturedAt: Date = .now) async throws -> CaptureOutcome {
        let context = ModelContext(container)

        // 1.
        let movement = Movement(
            source: .yappy, direction: .outflow, amount: 0, occurredAt: capturedAt, capturedAt: capturedAt,
            parseStatus: .failed, parseIssues: Set(ParseIssue.allCases))
        movement.rawContent = content
        context.insert(movement)
        try context.save()
        observer.rawSaved(movementID: movement.id)

        // 2–3.
        do {
            ParseApplier.apply(try parser.parseYappy(content), to: movement)
        } catch {
            logger.error("Parseo de Yappy falló, queda failed: \(error.localizedDescription, privacy: .public)")
        }

        // Deduplicación por confirmación + dirección (SPEC §2, C11). Sin confirmación o sin
        // dirección no hay dedup (C3).
        if let existing = try duplicate(of: movement, in: context) {
            // Se leen antes de borrar: un modelo borrado ya no se puede leer.
            let (id, status, issues) = (movement.id, movement.parseStatus, movement.parseIssues)
            context.delete(movement)
            try context.save()
            observer.saved(movementID: id, outcome: .duplicate(existing: existing), status: status, issues: issues)
            await backup.runIfDue()
            return .duplicate(existing: existing)
        }

        // 4.
        try context.save()
        observer.saved(
            movementID: movement.id, outcome: .created(movement.id),
            status: movement.parseStatus, issues: movement.parseIssues)

        await finish(movement.id)
        return .created(movement.id)
    }

    private func duplicate(of movement: Movement, in context: ModelContext) throws -> UUID? {
        guard
            let confirmation = movement.confirmation,
            !movement.parseIssues.contains(.direction)
        else { return nil }
        let target: String? = confirmation
        let directionRaw = movement.directionRaw
        let newID = movement.id
        var descriptor = FetchDescriptor<Movement>(
            predicate: #Predicate {
                $0.confirmation == target && $0.directionRaw == directionRaw && $0.id != newID
            },
            sortBy: [SortDescriptor(\.capturedAt)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.id
    }

    // 5–6.
    private func finish(_ id: UUID) async {
        await notifier.notify(movementID: id)
        await backup.runIfDue()
    }

    private static func json(_ inputs: CardRawInputs) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(inputs)).flatMap { String(data: $0, encoding: .utf8) }
    }
}
