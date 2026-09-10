import SwiftUI

public struct TaskInputView: View {
    let onAdd: (String, Bool, Date?) -> Void

    @State private var taskTitle: String = ""
    @State private var isRepeat: Bool = false
    @State private var selectedDays: Int? = nil
    @State private var showDueMenu: Bool = false
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) var colorScheme

    public init(onAdd: @escaping (String, Bool, Date?) -> Void) {
        self.onAdd = onAdd
    }

    public var body: some View {
        HStack(spacing: 10) {
            // Leading Solid Dot (Seamlessly aligned with tasks)
            ZStack {
                Circle()
                    .fill(
                        isFocused
                            ? (colorScheme == .dark ? Color.white : Color.black)
                            : Color.gray.opacity(0.35)
                    )
                    .frame(width: 10, height: 10)
                    .shadow(
                        color: isFocused
                            ? (colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.2))
                            : Color.clear,
                        radius: 4
                    )
            }
            .frame(width: 24, height: 24)

            // Text Input Field (Premium Typography, completely borderless)
            TextField("new task...", text: $taskTitle)
                .textFieldStyle(.plain)
                .font(.premium(14, weight: .regular))
                .tracking(-0.15)
                .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                .tint(colorScheme == .dark ? Color.white : Color.black)
                .focused($isFocused)
                .onSubmit {
                    submitTask()
                }

            // Controls: Repeat & Due (Pure typography, no leading icons, dark when selected)
            HStack(spacing: 10) {
                // Repeat button (Mutually exclusive with Due)
                Button(action: {
                    isRepeat.toggle()
                    if isRepeat {
                        selectedDays = nil
                        showDueMenu = false
                    }
                }) {
                    Text("repeat")
                        .font(.premium(12.5, weight: isRepeat ? .semibold : .regular))
                        .foregroundColor(
                            isRepeat
                                ? (colorScheme == .dark ? Color.white : Color.black)
                                : Color.gray
                        )
                }
                .buttonStyle(.plain)

                // Due button with popover for 1..5 days (Mutually exclusive with Repeat)
                Button(action: {
                    if selectedDays != nil {
                        selectedDays = nil
                    } else {
                        isRepeat = false
                        showDueMenu.toggle()
                    }
                }) {
                    Text(dueButtonTitle)
                        .font(.premium(12.5, weight: selectedDays != nil ? .semibold : .regular))
                        .foregroundColor(
                            selectedDays != nil
                                ? (colorScheme == .dark ? Color.white : Color.black)
                                : Color.gray
                        )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showDueMenu, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(1...5, id: \.self) { days in
                            Button(action: {
                                selectedDays = days
                                isRepeat = false
                                showDueMenu = false
                            }) {
                                HStack {
                                    Text("due in \(days)")
                                        .font(.premium(12, weight: selectedDays == days ? .semibold : .regular))
                                        .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(6)
                    .frame(width: 110)
                    .liquidGlassPopover(cornerRadius: 10)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var dueButtonTitle: String {
        if let days = selectedDays {
            return "due in \(days)"
        }
        return "due"
    }

    private func submitTask() {
        let trimmed = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let dueDate: Date?
        if let days = selectedDays, !isRepeat {
            dueDate = Calendar.current.date(byAdding: .day, value: days, to: Date())
        } else {
            dueDate = nil
        }

        onAdd(trimmed, isRepeat, isRepeat ? nil : dueDate)

        taskTitle = ""
        isRepeat = false
        selectedDays = nil
    }
}
