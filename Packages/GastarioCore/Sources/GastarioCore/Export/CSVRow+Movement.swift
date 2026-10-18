import Foundation

extension CSVRow {
    public init(_ movement: Movement) {
        self.init(
            occurredAt: movement.occurredAt, capturedAt: movement.capturedAt,
            source: movement.sourceRaw, direction: movement.direction, amount: movement.amount,
            counterparty: movement.counterparty, cardName: movement.cardName,
            yappyMessage: movement.yappyMessage, confirmation: movement.confirmation,
            city: movement.city, latitude: movement.latitude, longitude: movement.longitude,
            note: movement.note, parseStatus: movement.parseStatusRaw,
            attachmentCount: movement.attachments.count)
    }
}
