import Foundation

/// Avisos de `CaptureService` a la bitácora (SPEC Fase 7a). No cambian el orden del pipeline:
/// solo dicen hasta dónde llegó.
@MainActor
public protocol CaptureObserver {
    /// Después del `save()` del paso 1: el crudo ya está en el store.
    func rawSaved(movementID: UUID)
    /// Después del paso 4, o después de borrar un duplicado.
    func saved(movementID: UUID, outcome: CaptureOutcome, status: ParseStatus, issues: Set<ParseIssue>)
}

public struct NoopCaptureObserver: CaptureObserver {
    public init() {}
    public func rawSaved(movementID: UUID) {}
    public func saved(movementID: UUID, outcome: CaptureOutcome, status: ParseStatus, issues: Set<ParseIssue>) {}
}

/// Escribe los avisos de una invocación en la bitácora. El intent crea uno por invocación.
public struct CaptureLogObserver: CaptureObserver {
    private let log: CaptureLog
    private let invocation: UUID

    public init(log: CaptureLog, invocation: UUID) {
        self.log = log
        self.invocation = invocation
    }

    public func rawSaved(movementID: UUID) {
        log.record(.rawSaved(invocation, movementID: movementID))
    }

    public func saved(movementID: UUID, outcome: CaptureOutcome, status: ParseStatus, issues: Set<ParseIssue>) {
        log.record(.saved(invocation, movementID: movementID, outcome: outcome, status: status, issues: issues))
    }
}
