import Foundation
import GastarioParsing

/// Título y cuerpo de la notificación de un movimiento capturado (`INTENT.md`, Notificaciones).
public struct NotificationText: Equatable, Sendable {
    public let title: String
    public let body: String

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }

    public static func build(
        source: Source, direction: Direction, amount: Decimal, counterparty: String?,
        cardName: String?, status: ParseStatus, issues: Set<ParseIssue>
    ) -> NotificationText {
        if status == .failed {
            // El INTENT solo define el texto de Yappy; una tarjeta `failed` (el parser falló)
            // usa el mismo patrón.
            return review(source == .card
                ? "No pude leer un pago con tarjeta, revísalo en la app."
                : "No pude leer un Yappy, revísalo en la app.")
        }

        let missingAmount = issues.contains(.amount)
        let missingMerchant = issues.contains(.counterparty)
        if source == .card && (missingAmount || missingMerchant) {
            let card = cardName ?? "tarjeta"
            let missing = switch (missingAmount, missingMerchant) {
            case (true, true): "el monto ni el comercio"
            case (true, false): "el monto"
            default: "el comercio"
            }
            return review("Pagaste con \(card), pero no pude leer \(missing). Complétalo en la app.")
        }

        // Un Yappy `partial` sin contraparte pregunta igual, sin el "en …".
        let money = MovementPresentation.currencyText(amount)
        switch direction {
        case .outflow:
            return NotificationText(
                title: "Gasto",
                body: counterparty.map { "¿En qué gastaste \(money) en \($0)?" } ?? "¿En qué gastaste \(money)?")
        case .inflow:
            return NotificationText(
                title: "Ingreso",
                body: counterparty.map { "¿Por qué te enviaron \(money)? (\($0))" } ?? "¿Por qué te enviaron \(money)?")
        }
    }

    private static func review(_ body: String) -> NotificationText {
        NotificationText(title: "Revisar movimiento", body: body)
    }
}
