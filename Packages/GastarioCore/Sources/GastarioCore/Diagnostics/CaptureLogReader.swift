import Foundation

/// Hasta dónde llegó una invocación de un intent, según la tabla de interpretación de la
/// SPEC (Fase 7a). En orden: cada etapa implica las anteriores.
public enum CaptureStage: Int, Comparable, Sendable {
    /// Hay eventos de la invocación pero ningún `received`: no debería pasar.
    case unknown
    /// El proceso murió antes del primer guardado (abriendo el store o porque iOS lo mató).
    case received
    /// El crudo se guardó; murió entre el parseo y el segundo guardado.
    case rawSaved
    /// Guardado; murió notificando o respaldando. El movimiento existe.
    case saved
    /// El store lanzó.
    case error
    /// Terminó.
    case done

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    public var title: String {
        switch self {
        case .unknown: "Sin inicio registrado"
        case .received: "Murió antes de guardar"
        case .rawSaved: "Murió después de guardar el crudo"
        case .saved: "Murió notificando o respaldando"
        case .error: "El store falló"
        case .done: "Completa"
        }
    }
}

/// Los eventos de una invocación, en orden.
public struct CaptureInvocation: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let events: [CaptureLogEvent]

    public var received: CaptureLogEvent? { events.first { $0.ev == .received } }
    public var startedAt: Date { (received ?? events[0]).t }
    public var movementID: UUID? { events.lazy.compactMap(\.movementID).first }
    public var errorMessage: String? { events.first { $0.ev == .error }?.message }

    /// Sin `received` es `unknown` aunque haya pasos posteriores: la invocación no se puede leer
    /// con la tabla de interpretación y tiene que verse como anómala.
    public var stage: CaptureStage {
        guard received != nil else { return .unknown }
        if events.contains(where: { $0.ev == .done }) { return .done }
        if events.contains(where: { $0.ev == .error }) { return .error }
        if events.contains(where: { $0.ev == .saved }) { return .saved }
        if events.contains(where: { $0.ev == .rawSaved }) { return .rawSaved }
        return .received
    }

    public var isComplete: Bool { stage == .done }

    /// Dos `pid` en la misma invocación: iOS relanzó el proceso a mitad de la captura.
    public var pidChanged: Bool { Set(events.map(\.pid)).count > 1 }
}

public struct CaptureLogSummary: Equatable, Sendable {
    /// Ordenadas por inicio, de la más vieja a la más nueva.
    public var invocations: [CaptureInvocation]
    public var deletions: [CaptureLogEvent]
    public var unreadableLines: Int

    /// Invocaciones que empezaron en el intervalo. Ninguna cerca de la hora de un pago que el
    /// CSV viejo tiene significa que el intent no se invocó.
    public func invocations(from start: Date, to end: Date) -> [CaptureInvocation] {
        invocations.filter { $0.startedAt >= start && $0.startedAt <= end }
    }

    /// El borrado de un movimiento, si se registró: distingue "se borró a mano" de "desapareció".
    public func deletion(of movementID: UUID) -> CaptureLogEvent? {
        deletions.first { $0.movementID == movementID }
    }
}

/// Lee las líneas de la bitácora. Función pura: una línea que no se puede leer se cuenta y se
/// salta sin perder las demás.
public enum CaptureLogReader {
    public static func summarize(_ lines: [String]) -> CaptureLogSummary {
        let decoder = CaptureLogCoding.decoder()
        var byInvocation: [UUID: [CaptureLogEvent]] = [:]
        var deletions: [CaptureLogEvent] = []
        var unreadable = 0

        for line in lines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            guard let event = try? decoder.decode(CaptureLogEvent.self, from: Data(line.utf8)) else {
                unreadable += 1
                continue
            }
            if event.ev == .deleted {
                deletions.append(event)
            } else if let inv = event.inv {
                byInvocation[inv, default: []].append(event)
            }
        }

        let invocations = byInvocation
            .map { CaptureInvocation(id: $0.key, events: $0.value.sorted { $0.t < $1.t }) }
            .sorted { $0.startedAt < $1.startedAt }
        return CaptureLogSummary(
            invocations: invocations,
            deletions: deletions.sorted { $0.t < $1.t },
            unreadableLines: unreadable)
    }
}
