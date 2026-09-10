import Foundation

public struct TaskItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public var title: String
    public var isCompleted: Bool
    public var completedAt: Date?
    public var isRepeat: Bool
    public var dueDate: Date?
    public let createdAt: Date
    public var lastResetDate: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        isRepeat: Bool = false,
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        lastResetDate: Date? = nil
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.isRepeat = isRepeat
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.lastResetDate = lastResetDate
    }

    /// End of day (23:59:59) timestamp for the scheduled due date
    public var deadlineDate: Date? {
        guard let dueDate = dueDate else { return nil }
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: dueDate)
        components.hour = 23
        components.minute = 59
        components.second = 59
        return calendar.date(from: components)
    }

    /// Urgency classification based on hours remaining until 23:59 of due date
    public enum Urgency {
        case none
        case upcoming   // > 24 hours
        case withinDay  // <= 24 hours (1 day)
        case within12h  // <= 12 hours
        case within6h   // <= 6 hours
        case overdue    // past deadline
    }

    public var urgency: Urgency {
        guard let deadline = deadlineDate, !isCompleted else { return .none }
        let remaining = deadline.timeIntervalSince(Date())
        if remaining < 0 {
            return .overdue
        } else if remaining <= 6 * 3600 {
            return .within6h
        } else if remaining <= 12 * 3600 {
            return .within12h
        } else if remaining <= 24 * 3600 {
            return .withinDay
        } else {
            return .upcoming
        }
    }

    /// Minimalist localized display for the due date
    public var dueLabel: String? {
        guard let dueDate = dueDate else { return nil }
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfDue = calendar.startOfDay(for: dueDate)
        let days = calendar.dateComponents([.day], from: startOfToday, to: startOfDue).day ?? 0
        if days < 0 {
            return "overdue"
        } else if days == 0 {
            return "today"
        } else if days <= 5 {
            return "due in \(days)"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US")
            formatter.dateFormat = "d MMM"
            return formatter.string(from: dueDate)
        }
    }
}
