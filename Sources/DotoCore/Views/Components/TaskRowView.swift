import SwiftUI

public struct TaskRowView: View {
    let task: TaskItem
    let onToggle: () -> Void
    let onDelete: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered: Bool = false

    public init(
        task: TaskItem,
        onToggle: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.task = task
        self.onToggle = onToggle
        self.onDelete = onDelete
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Task Completion Solid Dot (Concentric ring if repeat)
            TaskDot(
                isCompleted: task.isCompleted,
                isRepeat: task.isRepeat,
                onToggle: onToggle
            )

            // Task Title (Static width, can expand vertically across multiple lines)
            Text(task.title)
                .font(.premium(14, weight: .regular))
                .tracking(-0.15)
                .foregroundColor(
                    task.isCompleted
                        ? (colorScheme == .dark ? Color(white: 0.28) : Color(white: 0.72))
                        : (colorScheme == .dark ? Color.white : Color.black)
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2.5)

            // Badges
            HStack(spacing: 8) {
                // Due Date (Gri)
                if let dueLabel = task.dueLabel, !task.isCompleted {
                    Text(dueLabel)
                        .font(.premium(11.5, weight: .medium))
                        .tracking(0.1)
                        .foregroundColor(Color.gray)
                }

                // Delete Action (Micro ×: space is always reserved to prevent layout shift)
                Button(action: onDelete) {
                    Text("×")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(Color.gray.opacity(0.6))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1.0 : 0.0)
                .allowsHitTesting(isHovered)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .liquidGlassHover(isHovered: isHovered, cornerRadius: 7)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}
