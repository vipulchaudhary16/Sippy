import Foundation

public struct IntakeEntry: Codable, Equatable {
    public let date: Date
    public let ml: Int

    public init(date: Date, ml: Int) {
        self.date = date
        self.ml = ml
    }
}

/// Every drink the user logs, persisted as JSON.
public final class IntakeLog {
    /// What a glass counted as before entries carried an amount.
    public static let legacyGlassML = 250

    public private(set) var entries: [IntakeEntry]
    private let fileURL: URL?

    /// Pass `nil` for an in-memory log (tests).
    public init(fileURL: URL?) {
        self.fileURL = fileURL
        entries = fileURL.flatMap { try? Data(contentsOf: $0) }.map(Self.decode) ?? []
    }

    /// Reads the current format, or the original one (a bare array of timestamps, one per glass).
    static func decode(_ data: Data) -> [IntakeEntry] {
        if let entries = try? JSONDecoder().decode([IntakeEntry].self, from: data) {
            return entries.sorted { $0.date < $1.date }
        }
        if let dates = try? JSONDecoder().decode([Date].self, from: data) {
            return dates.sorted().map { IntakeEntry(date: $0, ml: legacyGlassML) }
        }
        return []
    }

    public static func defaultURL() -> URL {
        AppPaths.supportDirectory.appendingPathComponent("intake.json")
    }

    public func log(ml: Int, at date: Date = Date()) {
        entries.append(IntakeEntry(date: date, ml: ml))
        entries.sort { $0.date < $1.date }
        persist()
    }

    /// Removes the most recent entry (undo for an accidental tap).
    @discardableResult
    public func removeLast() -> IntakeEntry? {
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

    /// appear.mp3 plays once as the character walks in.
    public static var appearSound: URL? { sound(named: "appear") }

    /// cheer.mp3 plays when the user says they drank.
    public static var cheerSound: URL? { sound(named: "cheer") }

    /// knock.mp3 plays when the character knocks before a calendar event.
    public static var knockSound: URL? { sound(named: "knock") }

    /// `<name>.mp3` / .m4a / .wav / .aiff / .caf in the Character folder.
    private static func sound(named name: String) -> URL? {
        ["mp3", "m4a", "wav", "aiff", "aif", "caf"]
            .map { characterDirectory.appendingPathComponent("\(name).\($0)") }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
