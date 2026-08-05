import Foundation

/// Copies an accepted clip into the app's `Documents/Clips/` directory so it
/// survives past its original (ephemeral temp-directory) location — required
/// for history entries to still resolve after the app relaunches.
enum ClipStorage {
    private static var clipsDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let clips = documents.appendingPathComponent("Clips", isDirectory: true)
        try? FileManager.default.createDirectory(at: clips, withIntermediateDirectories: true)
        return clips
    }

    /// Copies `sourceURL` into persistent storage and returns the new URL.
    /// Returns `sourceURL` unchanged if the copy fails — analysis can still
    /// proceed on the original clip for this session, it just won't survive
    /// a relaunch.
    static func persist(_ sourceURL: URL) -> URL {
        let destination = clipsDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension)
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            return destination
        } catch {
            return sourceURL
        }
    }
}
