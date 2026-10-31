import Foundation

/// Una línea de la bitácora de captura (SPEC Fase 7a, C17). Un solo tipo plano para todos los
/// eventos: cada uno llena sus campos y los demás quedan fuera del JSON.
public struct CaptureLogEvent: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case process, received, rawSaved, saved, error, done, deleted
    }

    /// De dónde salió un borrado.
    public enum DeletionOrigin: String, Codable, Sendable {
        case list, debug
    }

    // Comunes. `t` y `pid` los pone `CaptureLog` al escribir.
    public var t: Date
    public var pid: Int32
    public var ev: Kind
    /// Invocación de un intent. No lo llevan `process` ni `deleted`.
    public var inv: UUID?

    // process
    public var version: String?
    public var build: String?

    // received (y deleted: la fuente del movimiento)
    public var src: String?
    public var inputs: CardParams?
    public var contentLength: Int?
    public var contentSHA256: String?

    // rawSaved, saved, deleted
    public var movementID: UUID?

    // saved
    public var outcome: String?
    public var existing: UUID?
    public var parseStatus: String?
    public var parseIssues: [String]?

    // error
    public var message: String?
    public var type: String?

    // deleted
    public var amount: String?
    public var counterparty: String?
    public var capturedAt: Date?
    public var from: DeletionOrigin?

    public init(ev: Kind, inv: UUID? = nil) {
        self.t = .distantPast
        self.pid = 0
        self.ev = ev
        self.inv = inv
    }
}

/// Los parámetros del intent de tarjeta tal como llegaron de Atajos, **antes** de convertir
/// `nil` en `""`: distinguir los dos es parte del diagnóstico (un Wallet que no manda el campo
/// frente a uno que lo manda vacío).
public struct CardParams: Codable, Equatable, Sendable {
    public var merchant: String?
    public var amount: String?
    public var cardName: String?
    public var city: String?
    public var latitude: Double?
    public var longitude: Double?

    public init(
        merchant: String?, amount: String?, cardName: String?,
        city: String?, latitude: Double?, longitude: Double?
    ) {
        self.merchant = merchant
        self.amount = amount
        self.cardName = cardName
        self.city = city
        self.latitude = latitude
        self.longitude = longitude
    }

    private enum CodingKeys: String, CodingKey {
        case merchant, amount, cardName, city, latitude, longitude
    }

    /// `encode` y no `encodeIfPresent`: un `nil` se escribe como `null` y no desaparece.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(merchant, forKey: .merchant)
        try container.encode(amount, forKey: .amount)
        try container.encode(cardName, forKey: .cardName)
        try container.encode(city, forKey: .city)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
}

extension CaptureLogEvent {
    public static func process(version: String, build: String) -> Self {
        var event = Self(ev: .process)
        event.version = version
        event.build = build
        return event
    }

    public static func receivedCard(_ inv: UUID, inputs: CardParams) -> Self {
        var event = Self(ev: .received, inv: inv)
        event.src = Source.card.rawValue
        event.inputs = inputs
        return event
    }

    /// Solo largo y hash: el correo sigue en Mail y el cuerpo crudo ya va al store.
    public static func receivedYappy(_ inv: UUID, contentLength: Int, contentSHA256: String) -> Self {
        var event = Self(ev: .received, inv: inv)
        event.src = Source.yappy.rawValue
        event.contentLength = contentLength
        event.contentSHA256 = contentSHA256
        return event
    }

    public static func rawSaved(_ inv: UUID, movementID: UUID) -> Self {
        var event = Self(ev: .rawSaved, inv: inv)
        event.movementID = movementID
        return event
    }

    public static func saved(
        _ inv: UUID, movementID: UUID, outcome: CaptureOutcome, status: ParseStatus, issues: Set<ParseIssue>
    ) -> Self {
        var event = Self(ev: .saved, inv: inv)
        event.movementID = movementID
        switch outcome {
        case .created:
            event.outcome = "created"
        case .duplicate(let existing):
            event.outcome = "duplicate"
            event.existing = existing
        }
        event.parseStatus = status.rawValue
        event.parseIssues = issues.map(\.rawValue).sorted()
        return event
    }

    public static func error(_ inv: UUID, _ error: any Error) -> Self {
        var event = Self(ev: .error, inv: inv)
        event.message = String(describing: error)
        event.type = String(describing: Swift.type(of: error))
        return event
    }

    public static func done(_ inv: UUID) -> Self {
        Self(ev: .done, inv: inv)
    }
}

/// JSON de la bitácora: claves ordenadas y fechas ISO 8601 con milisegundos y offset de Panamá.
enum CaptureLogCoding {
    static let panama = TimeZone(identifier: "America/Panama")!

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(formatter().string(from: date))
        }
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = formatter().date(from: text) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Fecha inválida: \(text)")
            }
            return date
        }
        return decoder
    }

    /// Uno nuevo por uso: `ISO8601DateFormatter` no es `Sendable` y se escriben pocas líneas.
    private static func formatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = panama
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}
