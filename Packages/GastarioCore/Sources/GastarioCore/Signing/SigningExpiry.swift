import Foundation

/// Cuándo avisar que vence la firma de la app (SPEC Fase 7b, C18). Con una cuenta gratis el
/// perfil dura 7 días; vencido, iOS no abre la app ni para los intents y las capturas se pierden.
public struct SigningExpiry: Equatable, Sendable {
    public let expiresAt: Date

    /// Con menos de esto, Ajustes y la lista avisan en rojo.
    public static let urgencyWindow: TimeInterval = 48 * 60 * 60
    /// La notificación llega esto antes del vencimiento.
    public static let reminderLead: TimeInterval = 24 * 60 * 60

    public init(expiresAt: Date) {
        self.expiresAt = expiresAt
    }

    /// Faltan menos de 48 h, o ya venció.
    public func isUrgent(now: Date) -> Bool {
        expiresAt.timeIntervalSince(now) < Self.urgencyWindow
    }

    /// 24 h antes del vencimiento, o `nil` si esa hora ya pasó: no se programa un aviso atrasado.
    public func reminderDate(now: Date) -> Date? {
        let date = expiresAt.addingTimeInterval(-Self.reminderLead)
        return date > now ? date : nil
    }

    /// "La app vence el …", en Panamá.
    public var settingsText: String {
        "La app vence el \(Self.dateText(expiresAt))"
    }

    public static let reminderTitle = "Gastario vence mañana"

    /// Dos puntos y no punto: la hora termina en "p. m." y quedaría "p. m.." .
    public var reminderBody: String {
        "Vence el \(Self.dateText(expiresAt)): reinstálala desde Xcode para no perder capturas."
    }

    /// Segunda línea del aviso de la lista.
    public static let reinstallHint = "Reinstálala desde Xcode para no perder capturas."

    /// Fecha y hora en `America/Panama` (nunca `.current`), en español de Panamá.
    static func dateText(_ date: Date) -> String {
        var style = Date.FormatStyle(date: .abbreviated, time: .shortened)
        style.timeZone = TimeZone(identifier: "America/Panama")!
        return date.formatted(style.locale(Locale(identifier: "es_PA")))
    }
}
