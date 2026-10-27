import AppKit

/// Thin wrappers around `NSOpenPanel`.
@MainActor
enum Panels {
    /// Asks the user for a folder. Returns `nil` when cancelled.
    static func chooseFolder(message: String, prompt: String, startingAt directory: URL? = nil) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = message
        panel.prompt = prompt
        panel.directoryURL = directory
        return panel.runModal() == .OK ? panel.url : nil
    }
}
