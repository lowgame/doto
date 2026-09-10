import SwiftUI

@MainActor
public struct DotoPopoverView: View {
    @ObservedObject var taskManager: TaskManager
    @ObservedObject var noteManager: NoteManager
    let isDetached: Bool
    let onToggleDetach: () -> Void

    @State private var showMenu: Bool = false
    @State private var showHistory: Bool = false
    @State private var showNotes: Bool = false
    @State private var copyFeedback: Bool = false
    @State private var confirmingDeleteId: UUID? = nil
    @AppStorage("appTheme") private var appTheme: String = "system"
    @Environment(\.colorScheme) var colorScheme

    public init(
        taskManager: TaskManager,
        noteManager: NoteManager? = nil,
        isDetached: Bool = false,
        onToggleDetach: @escaping () -> Void = {}
    ) {
        self.taskManager = taskManager
        self.noteManager = noteManager ?? NoteManager()
        self.isDetached = isDetached
        self.onToggleDetach = onToggleDetach
    }

    private var preferredScheme: ColorScheme? {
        switch appTheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    public var body: some View {
        VStack(spacing: 10) {
            topBarView

            if showHistory {
                historyView
            } else if showNotes {
                NotesView(noteManager: noteManager)
            } else {
                TaskInputView { title, isRepeat, dueDate in
                    taskManager.addTask(title: title, isRepeat: isRepeat, dueDate: dueDate)
                }
                .padding(.horizontal, 16)

                taskListSection
            }
        }
        .padding(.bottom, 12)
        .frame(width: 350)
        .liquidGlassWindow(cornerRadius: 14)
        .preferredColorScheme(preferredScheme)
    }

    // MARK: - Top Bar

    private var topBarView: some View {
        HStack(spacing: 8) {
            // Top-left Concentric Dot Button: Toggle History Tab
            ConcentricDotButton(isActive: showHistory) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    showNotes = false
                    showHistory.toggle()
                }
            }

            // Top-left Square Tab Button: Toggle Notes Tab ("karenin içi dolu iken")
            SquareTabButton(isActive: showNotes) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    showHistory = false
                    showNotes.toggle()
                }
            }

            if showHistory {
                Text("history")
                    .font(.premium(12, weight: .medium))
                    .foregroundColor(Color.gray)
                    .transition(.opacity)
            } else if showNotes {
                Text("notes")
                    .font(.premium(12, weight: .medium))
                    .foregroundColor(Color.gray)
                    .transition(.opacity)
            } else if copyFeedback {
                Text("copied")
                    .font(.premium(11, weight: .medium))
                    .foregroundColor(Color.gray)
                    .transition(.opacity)
            }

            Spacer()

            // Top-right Menu Dot (Pure minimal settings)
            MenuDot {
                showMenu.toggle()
            }
            .popover(isPresented: $showMenu, arrowEdge: .bottom) {
                menuPopoverContent
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Settings Popover (Fully Minimalist: Zero Border Divs)

    private var menuPopoverContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Theme Switcher: O (Light), ● (Dark), — (Auto)
            // Clicking dot OR text immediately switches theme
            HStack(spacing: 12) {
                themeButton(label: "Light", isCircleHollow: true, isSystem: false, value: "light")
                themeButton(label: "Dark", isCircleHollow: false, isSystem: false, value: "dark")
                themeButton(label: "Auto", isCircleHollow: false, isSystem: true, value: "system")
            }
            .padding(.vertical, 2)

            Divider()
                .background(Color.gray.opacity(0.2))

            Button(action: {
                taskManager.copyMarkdownToClipboard()
                showMenu = false
                withAnimation { copyFeedback = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { copyFeedback = false }
                }
            }) {
                Text("Copy to Clipboard (.md)")
                    .font(.premium(12, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.plain)

            Button(action: {
                showMenu = false
                taskManager.exportMarkdownToFile()
            }) {
                Text("Export to File (.md)...")
                    .font(.premium(12, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.plain)

            Divider()
                .background(Color.gray.opacity(0.2))

            Button(action: {
                showMenu = false
                onToggleDetach()
            }) {
                Text(isDetached ? "Dock to Menu Bar" : "Detach to Desktop (Float)")
                    .font(.premium(12, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.plain)

            if !taskManager.completedTasks.isEmpty {
                Button(action: {
                    showMenu = false
                    taskManager.clearCompleted()
                }) {
                    Text("Clear Completed")
                        .font(.premium(12, weight: .regular))
                        .foregroundColor(Color.gray)
                        .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
            }

            if !taskManager.deletedTasks.isEmpty {
                Button(action: {
                    showMenu = false
                    taskManager.clearDeletedTasks()
                }) {
                    Text("Clear History")
                        .font(.premium(12, weight: .regular))
                        .foregroundColor(Color.gray)
                        .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
            }

            Divider()
                .background(Color.gray.opacity(0.2))

            Button(action: {
                showMenu = false
                if let url = URL(string: "https://x.com/hiimthelowgame") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Text("@hiimthelowgame on X")
                    .font(.premium(12, weight: .regular))
                    .foregroundColor(Color.gray)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.plain)

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Text("Quit")
                    .font(.premium(12, weight: .regular))
                    .foregroundColor(Color.gray)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 210)
        .liquidGlassPopover(cornerRadius: 10)
    }

    private func themeButton(label: String, isCircleHollow: Bool, isSystem: Bool, value: String) -> some View {
        let isSelected = appTheme == value
        let primaryColor = colorScheme == .dark ? Color.white : Color.black

        return Button(action: {
            appTheme = value
        }) {
            HStack(spacing: 5) {
                if isSystem {
                    Text("—")
                        .font(.premium(11.5, weight: isSelected ? .bold : .regular))
                } else if isCircleHollow {
                    Circle()
                        .strokeBorder(primaryColor, lineWidth: 1.2)
                        .frame(width: 8.5, height: 8.5)
                } else {
                    Circle()
                        .fill(primaryColor)
                        .frame(width: 8.5, height: 8.5)
                }

                Text(label)
                    .font(.premium(12, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? primaryColor : Color.gray)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Task List Section

    private var taskListSection: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 2) {
                ForEach(taskManager.allTasks) { task in
                    TaskRowView(
                        task: task,
                        onToggle: { taskManager.toggleCompletion(for: task.id) },
                        onDelete: { taskManager.deleteTask(id: task.id) }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 400)
    }

    // MARK: - History Section (Closed with ×)

    private var historyView: some View {
        VStack(alignment: .leading, spacing: 6) {
            if taskManager.deletedTasks.isEmpty {
                VStack(spacing: 6) {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                    Text("no dismissed tasks")
                        .font(.premium(12, weight: .regular))
                        .foregroundColor(Color.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: 200)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 2) {
                        ForEach(taskManager.deletedTasks) { task in
                            HStack(alignment: .top, spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(Color.gray.opacity(0.4))
                                        .frame(width: 6, height: 6)
                                }
                                .frame(width: 24, height: 24)

                                Text(task.title)
                                    .font(.premium(13.5, weight: .regular))
                                    .foregroundColor(Color.gray)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 2.5)

                                HStack(spacing: 8) {
                                    Button(action: {
                                        taskManager.restoreTask(id: task.id)
                                    }) {
                                        Text("restore")
                                            .font(.premium(11, weight: .medium))
                                            .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                                            .frame(height: 24)
                                    }
                                    .buttonStyle(.plain)

                                    // Permanent delete with two-click confirmation (inline, no modal)
                                    Button(action: {
                                        if confirmingDeleteId == task.id {
                                            // Second press: permanent delete
                                            withAnimation(.easeOut(duration: 0.2)) {
                                                taskManager.permanentlyDeleteTask(id: task.id)
                                                confirmingDeleteId = nil
                                            }
                                        } else {
                                            // First press: ask confirmation inline
                                            withAnimation(.easeInOut(duration: 0.15)) {
                                                confirmingDeleteId = task.id
                                            }
                                            // Auto-reset after 4 seconds if not confirmed
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                                                if confirmingDeleteId == task.id {
                                                    withAnimation(.easeInOut(duration: 0.15)) {
                                                        confirmingDeleteId = nil
                                                    }
                                                }
                                            }
                                        }
                                    }) {
                                        Text("×")
                                            .font(.system(size: 14, weight: confirmingDeleteId == task.id ? .bold : .light))
                                            .foregroundColor(
                                                confirmingDeleteId == task.id
                                                    ? (colorScheme == .dark ? Color.white : Color.black)
                                                    : Color.gray.opacity(0.4)
                                            )
                                            .scaleEffect(confirmingDeleteId == task.id ? 1.2 : 1.0)
                                            .frame(width: 24, height: 24)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 5)
                            .padding(.horizontal, 8)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 380)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
