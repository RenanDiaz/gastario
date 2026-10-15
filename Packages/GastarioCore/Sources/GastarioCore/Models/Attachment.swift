import Foundation
import SwiftData

@Model
public final class Attachment {
    public var id: UUID
    public var kindRaw: String
    /// Se guarda como archivo aparte, no infla la base.
    @Attribute(.externalStorage) public var data: Data?
    /// Solo `link`.
    public var url: URL?
    public var filename: String?
    public var addedAt: Date
    public var movement: Movement?

    public init(
        id: UUID = UUID(), kind: AttachmentKind, data: Data? = nil, url: URL? = nil,
        filename: String? = nil, addedAt: Date = .now
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.data = data
        self.url = url
        self.filename = filename
        self.addedAt = addedAt
    }

    public var kind: AttachmentKind {
        get { AttachmentKind(rawValue: kindRaw) ?? .link }
        set { kindRaw = newValue.rawValue }
    }
}
