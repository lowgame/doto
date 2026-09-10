import Foundation
import SwiftUI
import Combine

@MainActor
public final class NoteManager: ObservableObject {
    @Published public var notes: [NoteItem] = []
    @Published public var activeNoteId: UUID?

    private let fileManager = FileManager.default

    public init() {
        loadNotes()
        if notes.isEmpty {
            let initial = NoteItem(title: "scratch", content: "")
            notes.append(initial)
            activeNoteId = initial.id
            saveNotes()
        } else if activeNoteId == nil {
            activeNoteId = notes.first?.id
        }
    }

    public var activeNote: NoteItem? {
        guard let id = activeNoteId else { return notes.first }
        return notes.first(where: { $0.id == id }) ?? notes.first
    }

    public var activeNoteBinding: Binding<String> {
        Binding(
            get: { [weak self] in
                self?.activeNote?.content ?? ""
            },
            set: { [weak self] newContent in
                guard let self = self, let id = self.activeNoteId ?? self.notes.first?.id else { return }
                self.updateContent(id: id, newContent: newContent)
            }
        )
    }

    // MARK: - Mutations

    @discardableResult
    public func addNote(title: String? = nil) -> UUID {
        let noteNumber = notes.count + 1
        let defaultTitle = title ?? "note \(noteNumber)"
        let newNote = NoteItem(title: defaultTitle, content: "")
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            notes.append(newNote)
            activeNoteId = newNote.id
        }
        saveNotes()
        return newNote.id
    }

    public func selectNote(id: UUID) {
        withAnimation(.easeInOut(duration: 0.15)) {
            activeNoteId = id
        }
    }

    public func updateTitle(id: UUID, newTitle: String) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        notes[index].title = trimmed.isEmpty ? "note" : trimmed
        notes[index].updatedAt = Date()
        saveNotes()
    }

    public func updateContent(id: UUID, newContent: String) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].content = newContent
        notes[index].updatedAt = Date()
        saveNotes()
    }

    public func deleteNote(id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            notes.remove(at: index)
            if notes.isEmpty {
                let fresh = NoteItem(title: "scratch", content: "")
                notes.append(fresh)
                activeNoteId = fresh.id
            } else if activeNoteId == id {
                let nextIndex = min(index, notes.count - 1)
                activeNoteId = notes[nextIndex].id
            }
        }
        saveNotes()
    }

    // MARK: - Search

    public func searchNotes(query: String) -> [NoteItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return notes }
        return notes.filter { note in
            note.title.localizedCaseInsensitiveContains(trimmed) ||
            note.content.localizedCaseInsensitiveContains(trimmed)
        }
    }

    // MARK: - Persistence (Local JSON + iCloud Drive Mirror)

    private var localDataURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let appFolder = appSupport.appendingPathComponent("doto", isDirectory: true)
        if !fileManager.fileExists(atPath: appFolder.path) {
            try? fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true)
        }
        return appFolder.appendingPathComponent("notes.json")
    }

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private var iCloudDocsURL: URL? {
        guard !isRunningTests else { return nil }
        let home = fileManager.homeDirectoryForCurrentUser
        let cloudContainer = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        if fileManager.fileExists(atPath: cloudContainer.path) {
            let cloudDocs = cloudContainer.appendingPathComponent("doto", isDirectory: true)
            if !fileManager.fileExists(atPath: cloudDocs.path) {
                try? fileManager.createDirectory(at: cloudDocs, withIntermediateDirectories: true)
            }
            return cloudDocs.appendingPathComponent("notes.json")
        }
        return nil
    }

    public func saveNotes() {
        do {
            let data = try JSONEncoder().encode(notes)
            try data.write(to: localDataURL, options: .atomic)
            if let cloudURL = iCloudDocsURL {
                try? data.write(to: cloudURL, options: .atomic)
            }
        } catch {
            print("[doto] Failed to save notes: \(error)")
        }
    }

    private func loadNotes() {
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
                notes = try JSONDecoder().decode([NoteItem].self, from: data)
            } catch {
                print("[doto] Failed to decode notes: \(error)")
            }
        }
    }
}
