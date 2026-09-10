import XCTest
import SwiftUI
import AppKit
@testable import DotoCore

final class DotoTests: XCTestCase {

    func testDeadlineCalculation() {
        let calendar = Calendar.current
        let today = Date()
        let task = TaskItem(title: "Rapor teslimi", dueDate: today)

        guard let deadline = task.deadlineDate else {
            XCTFail("Deadline should not be nil")
            return
        }

        let components = calendar.dateComponents([.hour, .minute, .second], from: deadline)
        XCTAssertEqual(components.hour, 23)
        XCTAssertEqual(components.minute, 59)
        XCTAssertEqual(components.second, 59)
    }

    func testDueLabels() {
        let calendar = Calendar.current
        let today = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let todayTask = TaskItem(title: "Bugünkü iş", dueDate: today)
        let tomorrowTask = TaskItem(title: "Yarınki iş", dueDate: tomorrow)
        let yesterdayTask = TaskItem(title: "Dünkü iş", dueDate: yesterday)

        XCTAssertEqual(todayTask.dueLabel, "today")
        XCTAssertEqual(tomorrowTask.dueLabel, "due in 1")
        XCTAssertEqual(yesterdayTask.dueLabel, "overdue")
    }

    func testUrgencyLevels() {
        let calendar = Calendar.current
        let today = Date()
        let future = calendar.date(byAdding: .day, value: 3, to: today)!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let futureTask = TaskItem(title: "Gelecek", dueDate: future)
        XCTAssertEqual(futureTask.urgency, .upcoming)

        let todayTask = TaskItem(title: "Bugün biten", dueDate: today)
        XCTAssertTrue(todayTask.urgency == .withinDay || todayTask.urgency == .within12h || todayTask.urgency == .within6h)

        let overdueTask = TaskItem(title: "Gecikmiş", dueDate: yesterday)
        XCTAssertEqual(overdueTask.urgency, .overdue)

        let completedTask = TaskItem(title: "Biten", isCompleted: true, dueDate: today)
        XCTAssertEqual(completedTask.urgency, .none, "Completed tasks should have urgency .none")
    }

    @MainActor
    func testTaskAdditionAndSorting() {
        let manager = TaskManager()
        let initialCount = manager.tasks.count

        manager.addTask(title: "Yeni Test Görevi", isRepeat: true, dueDate: nil)

        XCTAssertEqual(manager.tasks.count, initialCount + 1)
        XCTAssertTrue(manager.activeTasks.contains { $0.title == "Yeni Test Görevi" })

        // Find and toggle completion
        guard let added = manager.tasks.first(where: { $0.title == "Yeni Test Görevi" }) else {
            XCTFail("Added task not found")
            return
        }

        manager.toggleCompletion(for: added.id)

        // After completion, it should move from active to completed
        XCTAssertFalse(manager.activeTasks.contains { $0.id == added.id })
        XCTAssertTrue(manager.completedTasks.contains { $0.id == added.id })

        // Clean up
        manager.deleteTask(id: added.id)
    }

    @MainActor
    func testRepeatAndDueMutualExclusivity() {
        let manager = TaskManager()
        manager.addTask(title: "Repeat task test", isRepeat: true, dueDate: Date())
        guard let task = manager.tasks.first(where: { $0.title == "Repeat task test" }) else {
            XCTFail("Task should exist")
            return
        }
        XCTAssertTrue(task.isRepeat)
        XCTAssertNil(task.dueDate, "Repeat task must never have a dueDate")
        manager.deleteTask(id: task.id)
    }

    @MainActor
    func testPermanentlyDeleteTaskFromHistory() {
        let manager = TaskManager()
        manager.addTask(title: "Task to be purged", isRepeat: false, dueDate: nil)
        guard let task = manager.tasks.first(where: { $0.title == "Task to be purged" }) else {
            XCTFail("Task should exist")
            return
        }
        let taskId = task.id
        // Dismiss with x
        manager.deleteTask(id: taskId)
        XCTAssertTrue(manager.deletedTasks.contains { $0.id == taskId })

        // Permanently purge
        manager.permanentlyDeleteTask(id: taskId)
        XCTAssertFalse(manager.deletedTasks.contains { $0.id == taskId })
        XCTAssertFalse(manager.tasks.contains { $0.id == taskId })
    }

    @MainActor
    func testDailyResetAtMidnightForRepeatTasks() {
        let manager = TaskManager()
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!

        // Create a repeating task completed yesterday
        let repeatTaskId = UUID()
        let repeatTask = TaskItem(
            id: repeatTaskId,
            title: "Her gün su iç",
            isCompleted: true,
            completedAt: yesterday,
            isRepeat: true
        )

        // Create a non-repeating task completed yesterday
        let normalTaskId = UUID()
        let normalTask = TaskItem(
            id: normalTaskId,
            title: "Tek seferlik proje",
            isCompleted: true,
            completedAt: yesterday,
            isRepeat: false
        )

        manager.tasks.append(repeatTask)
        manager.tasks.append(normalTask)

        // Simulate midnight / day changed check
        manager.checkAndPerformDailyReset()

        // The repeating task MUST be reset to isCompleted = false
        let updatedRepeat = manager.tasks.first(where: { $0.id == repeatTaskId })
        XCTAssertNotNil(updatedRepeat)
        XCTAssertFalse(updatedRepeat!.isCompleted, "Repeating task should reset to uncompleted at 00:00")
        XCTAssertNil(updatedRepeat!.completedAt)

        // The normal task MUST stay completed
        let updatedNormal = manager.tasks.first(where: { $0.id == normalTaskId })
        XCTAssertNotNil(updatedNormal)
        XCTAssertTrue(updatedNormal!.isCompleted, "Non-repeating task should stay completed")

        // Clean up
        manager.deleteTask(id: repeatTaskId)
        manager.deleteTask(id: normalTaskId)
    }

    @MainActor
    func testMarkdownExportGeneration() {
        let manager = TaskManager()
        let md = manager.generateMarkdown()

        XCTAssertTrue(md.contains("# todo"))
        XCTAssertTrue(md.contains("## Active"))
        XCTAssertTrue(md.contains("## Completed"))
    }

    @MainActor
    func testGenerateMarketingScreenshots() {
        let manager = TaskManager()
        let sampleTasks = [
            TaskItem(title: "Morning focus session", isCompleted: false, isRepeat: true),
            TaskItem(title: "Refactor core design system tokens", isCompleted: false, dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date())),
            TaskItem(title: "Ship doto to macOS menu bar", isCompleted: false, dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())),
            TaskItem(title: "Audit liquid glass specular reflections", isCompleted: true, completedAt: Date(), isRepeat: false),
            TaskItem(title: "Archive previous sprint notes", isCompleted: true, completedAt: Date(), isRepeat: false)
        ]
        manager.tasks = sampleTasks

        let artifactDir = "/Users/ahmetkamercivi/.gemini/antigravity/brain/9cc66d99-0f43-42e2-a81e-c052da4fc5b6"

        // Render Dark Mode
        let darkView = DotoPopoverView(taskManager: manager)
            .environment(\.colorScheme, .dark)
            .frame(width: 350, height: 460)

        let darkWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 460),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let darkHosting = NSHostingView(rootView: darkView)
        darkHosting.frame = NSRect(x: 0, y: 0, width: 350, height: 460)
        darkWindow.contentView = darkHosting
        darkHosting.layoutSubtreeIfNeeded()

        if let rep = darkHosting.bitmapImageRepForCachingDisplay(in: darkHosting.bounds) {
            darkHosting.cacheDisplay(in: darkHosting.bounds, to: rep)
            if let png = rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: "\(artifactDir)/doto_actual_ui_dark.png"))
            }
        }

        // Render Light Mode
        let lightView = DotoPopoverView(taskManager: manager)
            .environment(\.colorScheme, .light)
            .frame(width: 350, height: 460)

        let lightWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 460),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let lightHosting = NSHostingView(rootView: lightView)
        lightHosting.frame = NSRect(x: 0, y: 0, width: 350, height: 460)
        lightWindow.contentView = lightHosting
        lightHosting.layoutSubtreeIfNeeded()

        if let rep = lightHosting.bitmapImageRepForCachingDisplay(in: lightHosting.bounds) {
            lightHosting.cacheDisplay(in: lightHosting.bounds, to: rep)
            if let png = rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: "\(artifactDir)/doto_actual_ui_light.png"))
            }
        }
    }

    @MainActor
    func testNoteCreationAndAutoSave() {
        let noteManager = NoteManager()
        let initialCount = noteManager.notes.count
        XCTAssertGreaterThanOrEqual(initialCount, 1, "Should have at least 1 default note")

        let newId = noteManager.addNote(title: "meeting")
        XCTAssertEqual(noteManager.notes.count, initialCount + 1)
        XCTAssertEqual(noteManager.activeNoteId, newId)
        XCTAssertEqual(noteManager.activeNote?.title, "meeting")

        // Clean up
        noteManager.deleteNote(id: newId)
    }

    @MainActor
    func testNoteTitleAndContentUpdate() {
        let noteManager = NoteManager()
        let noteId = noteManager.addNote(title: "initial title")

        noteManager.updateTitle(id: noteId, newTitle: "renamed title")
        XCTAssertEqual(noteManager.notes.first(where: { $0.id == noteId })?.title, "renamed title")

        noteManager.updateContent(id: noteId, newContent: "Hello World!\nLine 2")
        XCTAssertEqual(noteManager.notes.first(where: { $0.id == noteId })?.content, "Hello World!\nLine 2")

        // Clean up
        noteManager.deleteNote(id: noteId)
    }

    @MainActor
    func testNoteDeletionAndFallback() {
        let noteManager = NoteManager()
        let id1 = noteManager.addNote(title: "tab A")
        let id2 = noteManager.addNote(title: "tab B")

        noteManager.deleteNote(id: id2)
        XCTAssertFalse(noteManager.notes.contains { $0.id == id2 })
        XCTAssertTrue(noteManager.notes.contains { $0.id == id1 })

        // Even if all notes are deleted, NoteManager must always guarantee at least 1 note exists
        for note in noteManager.notes {
            noteManager.deleteNote(id: note.id)
        }
        XCTAssertEqual(noteManager.notes.count, 1)
        XCTAssertNotNil(noteManager.activeNoteId)
    }

    @MainActor
    func testNoteSearch() {
        let noteManager = NoteManager()
        let id1 = noteManager.addNote(title: "Design System")
        noteManager.updateContent(id: id1, newContent: "Strict monochrome black and white palette")

        let id2 = noteManager.addNote(title: "Shopping List")
        noteManager.updateContent(id: id2, newContent: "Coffee beans, oat milk")

        let id3 = noteManager.addNote(title: "Architecture Plan")
        noteManager.updateContent(id: id3, newContent: "SwiftUI with AppKit NSTextView bridge")

        // Search by title match
        let resultsByTitle = noteManager.searchNotes(query: "design")
        XCTAssertTrue(resultsByTitle.contains { $0.id == id1 })
        XCTAssertFalse(resultsByTitle.contains { $0.id == id2 })

        // Search by content match
        let resultsByContent = noteManager.searchNotes(query: "coffee")
        XCTAssertTrue(resultsByContent.contains { $0.id == id2 })
        XCTAssertFalse(resultsByContent.contains { $0.id == id1 })

        // Search with case-insensitivity
        let resultsCase = noteManager.searchNotes(query: "SWIFTUI")
        XCTAssertTrue(resultsCase.contains { $0.id == id3 })

        // Empty query returns all notes
        let allNotes = noteManager.searchNotes(query: "")
        XCTAssertEqual(allNotes.count, noteManager.notes.count)

        // Non-matching query returns empty
        let emptyResults = noteManager.searchNotes(query: "nonexistentxyz123")
        XCTAssertTrue(emptyResults.isEmpty)

        // Clean up
        noteManager.deleteNote(id: id1)
        noteManager.deleteNote(id: id2)
        noteManager.deleteNote(id: id3)
    }

    @MainActor
    func testGenerateNotesScreenshots() {
        let noteManager = NoteManager()
        if let first = noteManager.notes.first {
            noteManager.updateContent(id: first.id, newContent: "")
            noteManager.selectNote(id: first.id)
        }

        let notesView = VStack(spacing: 10) {
            HStack(spacing: 8) {
                ConcentricDotButton(isActive: false) {}
                SquareTabButton(isActive: true) {}
                Text("notes")
                    .font(.premium(12, weight: .medium))
                    .foregroundColor(Color.gray)
                Spacer()
                MenuDot {}
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            NotesView(noteManager: noteManager)
        }
        .padding(.bottom, 12)
        .frame(width: 350, height: 460)
        .liquidGlassWindow(cornerRadius: 14)
        .environment(\.colorScheme, .dark)

        let artifactDir = "/Users/ahmetkamercivi/.gemini/antigravity/brain/9cc66d99-0f43-42e2-a81e-c052da4fc5b6"
        let darkWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 350, height: 460), styleMask: [.borderless], backing: .buffered, defer: false)
        let darkHosting = NSHostingView(rootView: notesView)
        darkHosting.frame = NSRect(x: 0, y: 0, width: 350, height: 460)
        darkWindow.contentView = darkHosting
        darkWindow.makeKeyAndOrderFront(nil)
        darkHosting.layoutSubtreeIfNeeded()

        if let rep = darkHosting.bitmapImageRepForCachingDisplay(in: darkHosting.bounds) {
            darkHosting.cacheDisplay(in: darkHosting.bounds, to: rep)
            if let png = rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: "\(artifactDir)/doto_notes_ui_dark.png"))
            }
        }

        // Render Light Mode
        let lightNotesView = VStack(spacing: 10) {
            HStack(spacing: 8) {
                ConcentricDotButton(isActive: false) {}
                SquareTabButton(isActive: true) {}
                Text("notes")
                    .font(.premium(12, weight: .medium))
                    .foregroundColor(Color.gray)
                Spacer()
                MenuDot {}
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            NotesView(noteManager: noteManager)
        }
        .padding(.bottom, 12)
        .frame(width: 350, height: 460)
        .liquidGlassWindow(cornerRadius: 14)
        .environment(\.colorScheme, .light)

        let lightWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 350, height: 460), styleMask: [.borderless], backing: .buffered, defer: false)
        let lightHosting = NSHostingView(rootView: lightNotesView)
        lightHosting.frame = NSRect(x: 0, y: 0, width: 350, height: 460)
        lightWindow.contentView = lightHosting
        lightHosting.layoutSubtreeIfNeeded()

        if let rep = lightHosting.bitmapImageRepForCachingDisplay(in: lightHosting.bounds) {
            lightHosting.cacheDisplay(in: lightHosting.bounds, to: rep)
            if let png = rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: "\(artifactDir)/doto_notes_ui_light.png"))
            }
        }
    }

    @MainActor
    func testSelectAllAndKeyboardShortcutsInNotesEditor() {
        let textView = PlaceholderTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
        textView.string = "Minimalist notes with zero distractions"

        // Initial state: cursor at end or start, length is 39
        XCTAssertEqual(textView.string.count, 39)

        // 1. Send Cmd+A (Select All)
        let eventCmdA = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "a",
            charactersIgnoringModifiers: "a",
            isARepeat: false,
            keyCode: 0
        )!

        let handledA = textView.performKeyEquivalent(with: eventCmdA)
        XCTAssertTrue(handledA, "Cmd+A should be handled by PlaceholderTextView")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 0, length: 39), "Cmd+A should select all text")

        // 2. Send Cmd+C (Copy)
        let eventCmdC = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "c",
            charactersIgnoringModifiers: "c",
            isARepeat: false,
            keyCode: 8
        )!
        let handledC = textView.performKeyEquivalent(with: eventCmdC)
        XCTAssertTrue(handledC, "Cmd+C should be handled by PlaceholderTextView")
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "Minimalist notes with zero distractions")

        // 3. Send Cmd+X (Cut)
        let eventCmdX = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "x",
            charactersIgnoringModifiers: "x",
            isARepeat: false,
            keyCode: 7
        )!
        let handledX = textView.performKeyEquivalent(with: eventCmdX)
        XCTAssertTrue(handledX, "Cmd+X should be handled by PlaceholderTextView")
        XCTAssertEqual(textView.string, "", "Cmd+X should cut selected text")

        // 4. Send Cmd+V (Paste)
        let eventCmdV = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "v",
            charactersIgnoringModifiers: "v",
            isARepeat: false,
            keyCode: 9
        )!
        let handledV = textView.performKeyEquivalent(with: eventCmdV)
        XCTAssertTrue(handledV, "Cmd+V should be handled by PlaceholderTextView")
        XCTAssertEqual(textView.string, "Minimalist notes with zero distractions", "Cmd+V should paste from pasteboard")
    }
}
