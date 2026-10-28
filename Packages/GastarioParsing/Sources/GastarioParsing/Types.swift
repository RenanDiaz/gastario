import Foundation

public enum Direction: String, Sendable, Codable, CaseIterable {
    case outflow
    case inflow
}

public enum ParseStatus: String, Sendable, Codable, CaseIterable {
    case ok
    case partial
    case failed
}

/// Qué no se pudo leer de un movimiento capturado (SPEC §2, C1).
public enum ParseIssue: String, Sendable, Codable, CaseIterable {
    case amount
    case counterparty
    case occurredAt
    case confirmation
    case direction
}

/// Parámetros tal como llegan a `LogCardMovementIntent`.
public struct CardRawInputs: Sendable, Codable, Equatable {
    public var merchant: String
    public var amount: String
    public var cardName: String
    public var city: String?
    public var latitude: Double?
    public var longitude: Double?

    public init(
        merchant: String, amount: String, cardName: String,
        city: String? = nil, latitude: Double? = nil, longitude: Double? = nil
    ) {
        self.merchant = merchant
        self.amount = amount
        self.cardName = cardName
        self.city = city
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// Resultado de parsear una captura de tarjeta. La dirección siempre es `outflow`.
public struct ParsedCard: Sendable, Equatable {
    /// `0` cuando no se pudo leer; en ese caso `issues` contiene `.amount`.
    public var amount: Decimal
    public var counterparty: String?
    public var cardName: String?
    public var city: String?
    public var latitude: Double?
    public var longitude: Double?
    public var status: ParseStatus
    public var issues: Set<ParseIssue>
}

/// Tipo de correo de Yappy reconocido.
public enum YappyKind: String, Sendable, CaseIterable {
    /// "Enviaste por Yappy" o "Enviaste con Yappy".
    case sent
    /// "Te enviaron por Yappy" o "Te enviaron con Yappy".
    case received
    /// "Pagaste por Yappy" o "Pagaste con Yappy" (pago a un comercio).
    case paid
    /// Yappy Comercial: "<negocio> ha recibido un pago por Yappy".
    case commercialReceived
    /// Yappy Comercial: "Recibiste una compra en línea por Yappy".
    case commercialOnlinePurchase

    public var direction: Direction {
        switch self {
        case .sent, .paid: .outflow
        case .received, .commercialReceived, .commercialOnlinePurchase: .inflow
        }
    }
}

/// Resultado de parsear el cuerpo de un correo de Yappy.
public struct ParsedYappy: Sendable, Equatable {
    public var kind: YappyKind?
    public var direction: Direction? { kind?.direction }
    public var amount: Decimal?
    public var counterparty: String?
    /// Vacío si el Yappy no trae mensaje; no es un issue.
    public var message: String
    public var confirmation: String?
    public var occurredAt: Date?
    public var status: ParseStatus
    public var issues: Set<ParseIssue>
}
