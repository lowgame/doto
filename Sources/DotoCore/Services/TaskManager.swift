import Foundation
import SwiftUI
import AppKit
import Combine

@MainActor
public final class TaskManager: ObservableObject {
    @Published public var tasks: [TaskItem] = []
    @Published public var deletedTasks: [TaskItem] = []

    private let fileManager = FileManager.default
    private let notificationManager = NotificationManager.shared
    private var dayChangeObserver: Any?
    private var wakeObserver: Any?

    public init() {
        loadTasks()
        loadHistory()
        checkAndPerformDailyReset()
        setupDayChangeObservers()
    }

    deinit {
        if let obs = dayChangeObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        if let obs = wakeObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    // MARK: - Filtered / Sorted Tasks

    /// Active (uncompleted) tasks, sorted by urgency and creation date
    public var activeTasks: [TaskItem] {
        tasks.filter { !$0.isCompleted }.sorted { (a, b) -> Bool in
            // If one has a due date and the other doesn't, due date comes first
            if let aDue = a.deadlineDate, let bDue = b.deadlineDate {
                return aDue < bDue
            } else if a.deadlineDate != nil {
                return true
            } else if b.deadlineDate != nil {
                return false
            } else {
                return a.createdAt < b.createdAt
            }
        }
    }

    /// Completed tasks, sent down below
    public var completedTasks: [TaskItem] {
        tasks.filter { $0.isCompleted }.sorted {
            ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt)
        }
    }

    /// All tasks in single flow: active first, then completed (no divider needed)
    public var allTasks: [TaskItem] {
        activeTasks + completedTasks
    }

    // MARK: - Task Mutations

    public func addTask(title: String, isRepeat: Bool = false, dueDate: Date? = nil) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let normalizedDue: Date?
        if isRepeat {
            // Repeat and Due are strictly mutually exclusive
            normalizedDue = nil
        } else if let dueDate = dueDate {
            normalizedDue = Calendar.current.startOfDay(for: dueDate)
        } else {
            normalizedDue = nil
        }

        let newTask = TaskItem(
            title: trimmed,
            isRepeat: isRepeat,
            dueDate: normalizedDue
        )

        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            tasks.insert(newTask, at: 0)
        }

        notificationManager.scheduleNotifications(for: newTask)
        saveTasks()
    }

    public func toggleCompletion(for taskId: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }

        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            tasks[index].isCompleted.toggle()
            if tasks[index].isCompleted {
                tasks[index].completedAt = Date()
                notificationManager.cancelNotifications(for: taskId)
            } else {
                tasks[index].completedAt = nil
                notificationManager.scheduleNotifications(for: tasks[index])
            }
        }

        saveTasks()
    }

    public func deleteTask(id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        let removedTask = tasks[index]
        withAnimation(.easeOut(duration: 0.25)) {
            tasks.remove(at: index)
            deletedTasks.insert(removedTask, at: 0)
        }
        notificationManager.cancelNotifications(for: id)
        saveTasks()
        saveHistory()
    }

    public func restoreTask(id: UUID) {
        guard let index = deletedTasks.firstIndex(where: { $0.id == id }) else { return }
        var restored = deletedTasks.remove(at: index)
        restored.isCompleted = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            tasks.insert(restored, at: 0)
        }
        notificationManager.scheduleNotifications(for: restored)
        saveTasks()
        saveHistory()
    }

    public func permanentlyDeleteTask(id: UUID) {
        withAnimation(.easeOut(duration: 0.2)) {
            deletedTasks.removeAll { $0.id == id }
        }
        saveHistory()
    }

    public func clearDeletedTasks() {
        withAnimation(.easeOut(duration: 0.25)) {
            deletedTasks.removeAll()
        }
        saveHistory()
    }

    public func clearCompleted() {
        withAnimation(.easeOut(duration: 0.3)) {
            tasks.removeAll { $0.isCompleted }
        }
        saveTasks()
    }

    // MARK: - Daily Reset (Her gün 00:00)

    public func checkAndPerformDailyReset() {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        var didResetAny = false

        for i in tasks.indices {
            // Repeat tasks that were completed on previous days reset to active
            if tasks[i].isRepeat && tasks[i].isCompleted {
                if let completedAt = tasks[i].completedAt, completedAt < todayStart {
                    tasks[i].isCompleted = false
                    tasks[i].completedAt = nil
                    tasks[i].lastResetDate = Date()
                    notificationManager.scheduleNotifications(for: tasks[i])
                    didResetAny = true
                }
            }
        }

        if didResetAny {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                objectWillChange.send()
            }
            saveTasks()
        }
    }

    private func setupDayChangeObservers() {
        dayChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkAndPerformDailyReset()
            }
        }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkAndPerformDailyReset()
            }
        }
    }

    // MARK: - Persistence & iCloud

    private var localDataURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let dotoFolder = appSupport.appendingPathComponent("doto", isDirectory: true)
        if !fileManager.fileExists(atPath: dotoFolder.path) {
            try? fileManager.createDirectory(at: dotoFolder, withIntermediateDirectories: true)
        }
        return dotoFolder.appendingPathComponent("tasks.json")
    }

    private var localHistoryURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let dotoFolder = appSupport.appendingPathComponent("doto", isDirectory: true)
        if !fileManager.fileExists(atPath: dotoFolder.path) {
            try? fileManager.createDirectory(at: dotoFolder, withIntermediateDirectories: true)
        }
        return dotoFolder.appendingPathComponent("history.json")
    }

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private var iCloudDocsURL: URL? {
        guard !isRunningTests else { return nil }
        let home = fileManager.homeDirectoryForCurrentUser
        let cloudDocs = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/doto", isDirectory: true)
        if fileManager.fileExists(atPath: home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs").path) {
            if !fileManager.fileExists(atPath: cloudDocs.path) {
                try? fileManager.createDirectory(at: cloudDocs, withIntermediateDirectories: true)
            }
            return cloudDocs.appendingPathComponent("tasks.json")
        }
        return nil
    }

    private var iCloudHistoryURL: URL? {
        guard !isRunningTests else { return nil }
        let home = fileManager.homeDirectoryForCurrentUser
        let cloudDocs = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/doto", isDirectory: true)
        if fileManager.fileExists(atPath: home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs").path) {
            if !fileManager.fileExists(atPath: cloudDocs.path) {
                try? fileManager.createDirectory(at: cloudDocs, withIntermediateDirectories: true)
            }
            return cloudDocs.appendingPathComponent("history.json")
        }
        return nil
    }

    private func saveTasks() {
        do {
            let data = try JSONEncoder().encode(tasks)
            try data.write(to: localDataURL, options: .atomic)

            if let cloudURL = iCloudDocsURL {
                try? data.write(to: cloudURL, options: .atomic)
            }
        } catch {
            print("[doto] Failed to save tasks: \(error)")
        }
    }

    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(deletedTasks)
            try data.write(to: localHistoryURL, options: .atomic)

            if let cloudURL = iCloudHistoryURL {
                try? data.write(to: cloudURL, options: .atomic)
            }
        } catch {
            print("[doto] Failed to save history: \(error)")
        }
    }

    private func loadHistory() {
        var loadedData: Data?

        if let cloudURL = iCloudHistoryURL, fileManager.fileExists(atPath: cloudURL.path) {
            let cloudMod = (try? fileManager.attributesOfItem(atPath: cloudURL.path)[.modificationDate] as? Date) ?? .distantPast
            let localMod = (try? fileManager.attributesOfItem(atPath: localHistoryURL.path)[.modificationDate] as? Date) ?? .distantPast

            if cloudMod >= localMod {
                loadedData = try? Data(contentsOf: cloudURL)
            }
        }

        if loadedData == nil && fileManager.fileExists(atPath: localHistoryURL.path) {
            loadedData = try? Data(contentsOf: localHistoryURL)
        }

        if let data = loadedData {
            do {
                deletedTasks = try JSONDecoder().decode([TaskItem].self, from: data)
            } catch {
                deletedTasks = []
            }
        } else {
            deletedTasks = []
        }
    }

    private func loadTasks() {
        // Try iCloud first if newer, otherwise local
        var loadedData: Data?

        if let cloudURL = iCloudDocsURL, fileManager.fileExists(atPath: cloudURL.path) {
            let cloudMod = (try? fileManager.attributesOfItem(atPath: cloudURL.path)[.modificationDate] as? Date) ?? .distantPast
            let localMod = (try? fileManager.attributesOfItem(atPath: localDataURL.path)[.modificationDate] as? Date) ?? .distantPast

            if cloudMod >= localMod {
                loadedData = try? Data(contentsOf: cloudURL)
            }
        }

        if loadedData == nil && fileManager.fileExists(atPath: localDataURL.path) {
            loadedData = try? Data(contentsOf: localDataURL)
        }

        if let data = loadedData {
            do {
                tasks = try JSONDecoder().decode([TaskItem].self, from: data)
            } catch {
                print("[doto] Failed to decode tasks: \(error)")
                tasks = []
            }
        } else {
            // Initial welcoming minimalist tasks
            tasks = [
                TaskItem(title: "first task", isRepeat: false),
                TaskItem(title: "daily habit", isRepeat: true),
                TaskItem(title: "project deadline", isRepeat: false, dueDate: Date())
            ]
            saveTasks()
        }
    }

    // MARK: - Markdown Export

    public func generateMarkdown() -> String {
        var lines: [String] = ["# todo", ""]

        lines.append("## Active")
        if activeTasks.isEmpty {
            lines.append("*(no active tasks)*")
        } else {
            for task in activeTasks {
                var extra = ""
                if task.isRepeat { extra += " ·· repeat" }
                if let due = task.dueLabel { extra += " [due: \(due)]" }
                lines.append("- [ ] \(task.title)\(extra)")
            }
        }

        lines.append("")
        lines.append("## Completed")
        if completedTasks.isEmpty {
            lines.append("*(no completed tasks)*")
        } else {
            for task in completedTasks {
                var extra = ""
                if task.isRepeat { extra += " ·· repeat" }
                lines.append("- [x] \(task.title)\(extra)")
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    public func copyMarkdownToClipboard() {
        let md = generateMarkdown()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(md, forType: .string)
    }

    public func exportMarkdownToFile() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "doto-\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)).md"
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let targetURL = panel.url {
            let md = generateMarkdown()
            try? md.write(to: targetURL, atomically: true, encoding: .utf8)
        }
    }
}
