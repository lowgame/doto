import Foundation

public struct NoteItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public var title: String
    public var content: String
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String = "note",
        content: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.title = trimmedTitle.isEmpty ? "note" : trimmedTitle
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
