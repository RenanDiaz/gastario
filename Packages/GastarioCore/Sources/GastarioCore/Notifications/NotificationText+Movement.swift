import Foundation

extension NotificationText {
    public static func build(for movement: Movement) -> NotificationText {
        build(
            source: movement.source, direction: movement.direction, amount: movement.amount,
            counterparty: movement.counterparty, cardName: movement.cardName,
            status: movement.parseStatus, issues: movement.parseIssues)
    }
}
