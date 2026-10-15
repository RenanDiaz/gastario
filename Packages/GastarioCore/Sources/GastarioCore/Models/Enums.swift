import Foundation

public enum Source: String, Sendable, Codable, CaseIterable {
    case card
    case yappy
    case manual
}

/// Campos que se pueden corregir a mano; el re-parseo no los toca (SPEC §2, C2).
public enum EditableField: String, Sendable, Codable, CaseIterable {
    case amount
    case counterparty
    case occurredAt
}

public enum AttachmentKind: String, Sendable, Codable, CaseIterable {
    case image
    case pdf
    case link
}
