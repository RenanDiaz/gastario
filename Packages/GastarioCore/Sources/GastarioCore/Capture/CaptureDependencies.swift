import Foundation
import GastarioParsing

public enum CaptureOutcome: Equatable, Sendable {
    case created(UUID)
    case duplicate(existing: UUID)
}

/// Paso 5 del pipeline de captura. La Fase 3 lo implementa con notificaciones locales.
@MainActor
public protocol MovementNotifier {
    func notify(movementID: UUID) async
}

/// Paso 6 del pipeline de captura. La Fase 5 lo implementa con el auto-export.
@MainActor
public protocol BackupTrigger {
    func runIfDue() async
}

public struct NoopNotifier: MovementNotifier {
    public init() {}
    public func notify(movementID: UUID) async {}
}

public struct NoopBackupTrigger: BackupTrigger {
    public init() {}
    public func runIfDue() async {}
}

/// Parseo inyectable: las pruebas usan uno que lanza para probar que el crudo ya está guardado.
public protocol CaptureParser: Sendable {
    func parseCard(_ inputs: CardRawInputs) throws -> ParsedCard
    func parseYappy(_ content: String) throws -> ParsedYappy
}

public struct DefaultCaptureParser: CaptureParser {
    public init() {}
    public func parseCard(_ inputs: CardRawInputs) throws -> ParsedCard { CardInputParser.parse(inputs) }
    public func parseYappy(_ content: String) throws -> ParsedYappy { YappyEmailParser.parse(content) }
}
