import SwiftUI

// MARK: - Minimalist Solid Task Completion Dot (with Repeat Concentric Ring)

public struct TaskDot: View {
    let isCompleted: Bool
    let isRepeat: Bool
    let onToggle: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered: Bool = false
    @State private var isPressed: Bool = false

    public init(
        isCompleted: Bool,
        isRepeat: Bool = false,
        onToggle: @escaping () -> Void
    ) {
        self.isCompleted = isCompleted
        self.isRepeat = isRepeat
        self.onToggle = onToggle
    }

    public var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isPressed = false
                }
            }
            onToggle()
        }) {
            ZStack {
                if isRepeat {
                    // Outer Concentric Ring (Çember) for Repeat Tasks
                    Circle()
                        .strokeBorder(
                            dotColor,
                            lineWidth: 1.2
                        )
                        .frame(width: 18, height: 18)

                    // Inner Dot
                    Circle()
                        .fill(dotColor)
                        .frame(
                            width: isCompleted ? 6 : 8,
                            height: isCompleted ? 6 : 8
                        )
                        .shadow(
                            color: !isCompleted && isHovered
                                ? (colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.2))
                                : .clear,
                            radius: 3
                        )
                } else {
                    // Regular Solid Dot
                    Circle()
                        .fill(dotColor)
                        .frame(
                            width: isCompleted ? 8 : 12,
                            height: isCompleted ? 8 : 12
                        )
                        .shadow(
                            color: !isCompleted && isHovered
                                ? (colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.2))
                                : .clear,
                            radius: 3
                        )
                }
            }
            .frame(width: 24, height: 24)
            .scaleEffect(isPressed ? 0.8 : 1.0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }

    private var dotColor: Color {
        if isCompleted {
            // Very faint grey when completed
            return colorScheme == .dark ? Color(white: 0.22) : Color(white: 0.78)
        } else {
            // Bold solid black (or white in dark mode)
            return colorScheme == .dark ? Color.white : Color.black
        }
    }
}

// MARK: - Top-Left Concentric Dot Menu Button (Dot with Ring Around It)

public struct ConcentricDotButton: View {
    let isActive: Bool
    let action: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered: Bool = false

    public init(isActive: Bool = false, action: @escaping () -> Void) {
        self.isActive = isActive
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                // Outer Ring (Çember)
                Circle()
                    .strokeBorder(
                        isActive || isHovered
                            ? (colorScheme == .dark ? Color.white : Color.black)
                            : Color.gray.opacity(0.5),
                        lineWidth: 1.2
                    )
                    .frame(width: 14, height: 14)

                // Center Dot
                Circle()
                    .fill(
                        isActive || isHovered
                            ? (colorScheme == .dark ? Color.white : Color.black)
                            : Color.gray.opacity(0.5)
                    )
                    .frame(width: 4, height: 4)
            }
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Top-Left Square Note Button (Hollow when inactive, Filled when active)

public struct SquareTabButton: View {
    let isActive: Bool
    let action: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered: Bool = false

    public init(isActive: Bool = false, action: @escaping () -> Void) {
        self.isActive = isActive
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                if isActive {
                    // Filled Square when active ("karenin içi dolu iken")
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(colorScheme == .dark ? Color.white : Color.black)
                        .frame(width: 11, height: 11)
                        .shadow(
                            color: colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.2),
                            radius: 3
                        )
                } else {
                    // Hollow Square when inactive
                    RoundedRectangle(cornerRadius: 2.5)
                        .strokeBorder(
                            isHovered
                                ? (colorScheme == .dark ? Color.white : Color.black)
                                : Color.gray.opacity(0.5),
                            lineWidth: 1.2
                        )
                        .frame(width: 11, height: 11)
                }
            }
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Top-Right Settings Menu Dot

public struct MenuDot: View {
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered: Bool = false

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        isHovered
                            ? (colorScheme == .dark ? Color.white : Color.black)
                            : Color.gray.opacity(0.55)
                    )
                    .frame(width: 6, height: 6)
            }
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}
