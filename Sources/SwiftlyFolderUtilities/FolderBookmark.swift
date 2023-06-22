//
//  FolderBookmark.swift
//  Chord Provider
//
//  © 2023 Nick Berendsen
//

import SwiftUI

/// Persistent folder utilities
public enum FolderBookmark {
    // Just a placeholder
}

extension FolderBookmark {
    enum BookmarkError: LocalizedError {
        case notFound
        case noKeyWindow
        case noFolderSelected

        public var description: String {
            switch self {
            case .noKeyWindow:
                return "Error retrieving key window"
            case .notFound:
                return "Error retrieving persistent bookmark data"
            case .noFolderSelected:
                return "There is no folder selected"
            }
        }

        public var errorDescription: String? {
            return description
        }
    }
}


extension FolderBookmark {

    /// Open a sheet to select a folder
    /// - Parameters:
    ///   - prompt: The text for the default button
    ///   - message: The message in the dialog
    ///   - bookmark: The name of the bookmark
    /// - Returns: The selected URL or an error when nothing is selected
    @MainActor public static func select(prompt: String, message: String, bookmark: String) async throws -> URL {
        /// Make sure we have a window to attach the sheet
        guard let window = NSApp.keyWindow else {
            throw BookmarkError.noKeyWindow
        }
        /// Get the last selected folder; defaults to 'Documents'
        let selection = getLastSelectedURL(bookmark: bookmark)
        let dialog = NSOpenPanel()
        dialog.showsResizeIndicator = true
        dialog.showsHiddenFiles = false
        dialog.canChooseFiles = false
        dialog.canChooseDirectories = true
        dialog.directoryURL = selection
        dialog.message = message
        dialog.prompt = prompt
        dialog.canCreateDirectories = true
        let result = await dialog.beginSheetModal(for: window)
        /// Throw an error if no folder is selected
        guard  result == .OK, let url = dialog.url else {
            throw BookmarkError.noFolderSelected
        }
        /// Create a persistent bookmark for the folder the user just selected
        _ = setPersistentFileURL(bookmark, url)
        /// Return the selected url
        return url
    }
}

extension FolderBookmark {

    /// Perform an action with a bookmark folder
    /// - Parameters:
    ///   - bookmark: The name of the bookmark
    ///   - action: The action for the bookmark folder
    public static func action(bookmark: String, action: (_ url: URL) async -> Void) async throws {
        guard let persistentURL = try FolderBookmark.getPersistentFileURL(bookmark) else {
            throw BookmarkError.notFound
        }
        /// Make sure the security-scoped resource is released when finished
        defer {
            persistentURL.stopAccessingSecurityScopedResource()
        }
        /// Start accessing a security-scoped resource
        _ = persistentURL.startAccessingSecurityScopedResource()
        /// Execute the action
        await action(persistentURL)
    }
}

extension FolderBookmark {

    /// Open an URL in the Finder
    /// - Parameter url: The URL to open
    public static func openInFinder(url: URL?) {
        guard let url = url else {
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

extension FolderBookmark {

    /// Get the URL of a bookmark
    /// - Parameter bookmark: The name of the bookmark
    /// - Returns: The URL of the bookmark if found, else 'Documents'
    public static func getLastSelectedURL(bookmark: String) -> URL {
        guard let persistentURL = try? FolderBookmark.getPersistentFileURL(bookmark) else {
            return FolderBookmark.getDocumentsDirectory()
        }
        return persistentURL
    }
}

private extension FolderBookmark {

    /// Set the sandbox bookmark
    /// - Parameters:
    ///   - bookmark: The name of the bookmark
    ///   - selectedURL: The URL of the bookmark
    /// - Returns: True or false if the bookmark is set
    static func setPersistentFileURL(_ bookmark: String, _ selectedURL: URL) -> Bool {
        do {
            let bookmarkData = try selectedURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: bookmark)
            return true
        } catch let error {
            print(error.localizedDescription)
            return false
        }
    }
}

private extension FolderBookmark {

    /// Get the sandbox bookmark
    /// - Parameter bookmark: The name of the bookmark
    /// - Returns: The URL of the bookmark
    static func getPersistentFileURL(_ bookmark: String) throws -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: bookmark) else {
            throw BookmarkError.notFound
        }
        do {
            var bookmarkDataIsStale = false
            let urlForBookmark = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &bookmarkDataIsStale
            )
            if bookmarkDataIsStale {
                _ = setPersistentFileURL(bookmark, urlForBookmark)
            }
            return urlForBookmark
        } catch {
            throw error
        }
    }
}

private extension FolderBookmark {

    /// Get the Documents directory
    /// - Returns: The users Documents directory
    static func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}
