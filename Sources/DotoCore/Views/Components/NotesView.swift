import SwiftUI
import AppKit

public struct NotesView: View {
    @ObservedObject var noteManager: NoteManager
    @Environment(\.colorScheme) var colorScheme

    @State private var editingTabId: UUID? = nil
    @State private var editedTitle: String = ""
    @FocusState private var isTitleFocused: Bool

    @State private var searchQuery: String = ""
    @State private var isSearching: Bool = false
    @FocusState private var isSearchFocused: Bool

    public init(noteManager: NoteManager) {
        self.noteManager = noteManager
    }

    private var displayedNotes: [NoteItem] {
        if isSearching && !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return noteManager.searchNotes(query: searchQuery)
        }
        return noteManager.notes
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Search Bar (Active when searching)
            if isSearching {
                searchBarView
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Tab Bar
            tabBar

            // Content Area / Empty Search Results
            if displayedNotes.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    Text("no notes match '\(searchQuery)'")
                        .font(.premium(12, weight: .regular))
                        .foregroundColor(Color.gray.opacity(0.5))
                    Spacer()
                }
                .frame(minHeight: 280, maxHeight: 340)
            } else {
                editorArea
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 400)
        .padding(.horizontal, 16)
        .onExitCommand {
            if isSearching {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isSearching = false
                    searchQuery = ""
                }
            }
        }
        .background(
            // Hidden Cmd+F shortcut button
            Button("") {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isSearching.toggle()
                    if isSearching {
                        isSearchFocused = true
                    } else {
                        searchQuery = ""
                    }
                }
            }
            .keyboardShortcut("f", modifiers: .command)
            .opacity(0)
        )
        .onChange(of: searchQuery) { _, query in
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let matches = noteManager.searchNotes(query: trimmed)
                if let first = matches.first, !matches.contains(where: { $0.id == noteManager.activeNoteId }) {
                    noteManager.selectNote(id: first.id)
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBarView: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.gray.opacity(0.6))
                .frame(width: 4, height: 4)
                .padding(.leading, 2)

            TextField("search notes...", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.premium(12, weight: .medium))
                .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                .tint(colorScheme == .dark ? Color.white : Color.black)
                .focused($isSearchFocused)

            if !searchQuery.isEmpty {
                Text("\(displayedNotes.count)")
                    .font(.premium(10.5, weight: .regular))
                    .foregroundColor(Color.gray.opacity(0.6))

                Button(action: {
                    searchQuery = ""
                }) {
                    Text("×")
                        .font(.system(size: 13, weight: .light))
                        .foregroundColor(Color.gray)
                        .frame(width: 14, height: 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isSearching = false
                    searchQuery = ""
                }
            }) {
                Text("done")
                    .font(.premium(11, weight: .medium))
                    .foregroundColor(Color.gray)
                    .padding(.horizontal, 4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
        )
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(displayedNotes) { note in
                        tabItem(for: note)
                    }

                    if !isSearching {
                        // Add Tab Button
                        Button(action: {
                            let newId = noteManager.addNote()
                            beginEditing(id: newId, currentTitle: noteManager.notes.last?.title ?? "note")
                        }) {
                            Text("+")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(Color.gray)
                                .frame(width: 22, height: 22)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }

            Spacer(minLength: 4)

            if !isSearching {
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        isSearching = true
                        isSearchFocused = true
                    }
                }) {
                    Text("search")
                        .font(.premium(11, weight: .regular))
                        .foregroundColor(Color.gray.opacity(0.7))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func tabItem(for note: NoteItem) -> some View {
        let isActive = noteManager.activeNoteId == note.id

        return Group {
            if editingTabId == note.id {
                // Inline Editable Title Field
                HStack(spacing: 4) {
                    TextField("tab title", text: $editedTitle)
                        .textFieldStyle(.plain)
                        .font(.premium(12, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                        .tint(colorScheme == .dark ? Color.white : Color.black)
                        .focused($isTitleFocused)
                        .onSubmit {
                            commitTitleEdit(for: note.id)
                        }
                        .frame(minWidth: 50, maxWidth: 100)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                )
            } else {
                // Static Tab Label
                Button(action: {
                    if isActive {
                        beginEditing(id: note.id, currentTitle: note.title)
                    } else {
                        noteManager.selectNote(id: note.id)
                    }
                }) {
                    HStack(spacing: 6) {
                        Text(note.title)
                            .font(.premium(12, weight: isActive ? .semibold : .regular))
                            .foregroundColor(
                                isActive
                                    ? (colorScheme == .dark ? Color.white : Color.black)
                                    : Color.gray
                            )

                        if isActive && noteManager.notes.count > 1 && !isSearching {
                            Button(action: {
                                noteManager.deleteNote(id: note.id)
                            }) {
                                Text("×")
                                    .font(.system(size: 12, weight: .light))
                                    .foregroundColor(Color.gray.opacity(0.6))
                                    .frame(width: 14, height: 14)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                isActive
                                    ? (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                                    : Color.clear
                            )
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture(count: 2).onEnded {
                    beginEditing(id: note.id, currentTitle: note.title)
                })
            }
        }
    }

    private func beginEditing(id: UUID, currentTitle: String) {
        editingTabId = id
        editedTitle = currentTitle
        isTitleFocused = true
    }

    private func commitTitleEdit(for id: UUID) {
        noteManager.updateTitle(id: id, newTitle: editedTitle)
        editingTabId = nil
    }

    // MARK: - Editor Area

    private var editorArea: some View {
        MinimalTextEditor(
            text: noteManager.activeNoteBinding,
            isDark: colorScheme == .dark
        )
        .id(noteManager.activeNoteId)
        .frame(minHeight: 330, maxHeight: 370)
        .padding(.vertical, 4)
    }
}

// MARK: - AppKit MinimalTextEditor & PlaceholderTextView

public struct MinimalTextEditor: NSViewRepresentable {
    @Binding var text: String
    var isDark: Bool
    var font: NSFont = .premium(13.5, weight: .regular)

    public init(text: Binding<String>, isDark: Bool, font: NSFont = .premium(13.5, weight: .regular)) {
        self._text = text
        self.isDark = isDark
        self.font = font
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let contentSize = scrollView.contentSize
        let textContainer = NSTextContainer(containerSize: NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        textContainer.lineFragmentPadding = 0

        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)

        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)

        let textView = PlaceholderTextView(frame: NSRect(origin: .zero, size: contentSize), textContainer: textContainer)
        textView.minSize = NSSize(width: 0.0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 0, height: 2)
        textView.font = font

        let textColor = isDark ? NSColor.white : NSColor(white: 0.1, alpha: 1.0)
        textView.textColor = textColor
        textView.insertionPointColor = textColor
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: textColor
        ]
        textView.placeholderOffset = 2.0
        textView.placeholderFont = font
        textView.placeholderColor = NSColor.gray.withAlphaComponent(0.4)
        textView.delegate = context.coordinator
        textView.allowsUndo = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        scrollView.documentView = textView
        context.coordinator.textView = textView

        return scrollView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? PlaceholderTextView else { return }
        if textView.string != text {
            let oldSelectedRange = textView.selectedRange()
            textView.string = text
            let safeLoc = min(oldSelectedRange.location, (text as NSString).length)
            textView.setSelectedRange(NSRange(location: safeLoc, length: 0))
        }
        let textColor = isDark ? NSColor.white : NSColor(white: 0.1, alpha: 1.0)
        textView.textColor = textColor
        textView.insertionPointColor = textColor
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: textColor
        ]
        textView.placeholderFont = font
        textView.placeholderColor = NSColor.gray.withAlphaComponent(0.4)
        textView.needsDisplay = true
    }

    public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MinimalTextEditor
        weak var textView: PlaceholderTextView?

        init(_ parent: MinimalTextEditor) {
            self.parent = parent
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string
            textView.needsDisplay = true
        }
    }
}

final class PlaceholderTextView: NSTextView {
    var placeholderString: String = "start typing..."
    var placeholderColor: NSColor = NSColor.gray.withAlphaComponent(0.4)
    var placeholderOffset: CGFloat = 2.0
    var placeholderFont: NSFont = .premium(13.5, weight: .regular)

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if string.isEmpty && !placeholderString.isEmpty {
            let font = self.font ?? placeholderFont
            let origin = textContainerOrigin
            let padding = textContainer?.lineFragmentPadding ?? 0
            let rect = NSRect(
                x: origin.x + padding + placeholderOffset,
                y: origin.y,
                width: bounds.width - origin.x - padding - placeholderOffset,
                height: bounds.height - origin.y
            )
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: placeholderColor
            ]
            let attrString = NSAttributedString(string: placeholderString, attributes: attrs)
            attrString.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == .command {
            let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""
            if chars == "a" || event.keyCode == 0 { // Cmd+A (Select All)
                selectAll(nil)
                return true
            } else if chars == "c" || event.keyCode == 8 { // Cmd+C (Copy)
                copy(nil)
                return true
            } else if chars == "v" || event.keyCode == 9 { // Cmd+V (Paste)
                paste(nil)
                return true
            } else if chars == "x" || event.keyCode == 7 { // Cmd+X (Cut)
                cut(nil)
                return true
            } else if chars == "z" || event.keyCode == 6 { // Cmd+Z (Undo)
                undoManager?.undo()
                return true
            }
        } else if flags == [.command, .shift] {
            let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""
            if chars == "z" || event.keyCode == 6 { // Cmd+Shift+Z (Redo)
                undoManager?.redo()
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

