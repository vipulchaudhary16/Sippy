import Foundation

/// Every glass the user logs, persisted as a JSON array of timestamps.
public final class IntakeLog {
    public private(set) var entries: [Date]
    private let fileURL: URL?

    /// Pass `nil` for an in-memory log (tests).
    public init(fileURL: URL?) {
        self.fileURL = fileURL
        if let url = fileURL,
           let data = try? Data(contentsOf: url),
           let dates = try? JSONDecoder().decode([Date].self, from: data) {
            entries = dates.sorted()
        } else {
            entries = []
        }
    }

    public static func defaultURL() -> URL {
        AppPaths.supportDirectory.appendingPathComponent("intake.json")
    }

    public func log(at date: Date = Date()) {
        entries.append(date)
        entries.sort()
        persist()
    }

    /// Removes the most recent entry (undo for an accidental tap).
    @discardableResult
    public func removeLast() -> Date? {
        guard let last = entries.popLast() else { return nil }
        persist()
        return last
    }

    private func persist() {
        guard let url = fileURL else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: url, options: .atomic)
        }
    }
}

public enum AppPaths {
    public static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Sippy", isDirectory: true)
    }

    /// Drop idle_*.png / walk_*.png / sip_*.png here to replace the built-in character.
    public static var characterDirectory: URL {
        supportDirectory.appendingPathComponent("Character", isDirectory: true)
    }

    /// cheer.mp3 / .m4a / .wav / .aiff in the Character folder plays when the user says they drank.
    public static var cheerSound: URL? {
        ["mp3", "m4a", "wav", "aiff", "aif", "caf"]
            .map { characterDirectory.appendingPathComponent("cheer.\($0)") }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
