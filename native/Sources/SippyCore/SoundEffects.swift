import Foundation

/// The short sounds the character makes. Each one can be the user's own file, a macOS system
/// sound, or nothing; the choice lives in `AppSettings.soundChoices` under the effect's raw value.
public enum SoundEffect: String, CaseIterable {
    case appear
    case cheer
    case walkOut
    case sad
    case knock

    public var title: String {
        switch self {
        case .appear: return "Walk-in"
        case .cheer: return "Cheer"
        case .walkOut: return "Walk-out"
        case .sad: return "Sad"
        case .knock: return "Knock"
        }
    }

    public var detail: String {
        switch self {
        case .appear: return "as the character arrives"
        case .cheer: return "when you log a drink"
        case .walkOut: return "as it walks off happy, across the screen"
        case .sad: return "when you snooze"
        case .knock: return "before a meeting"
        }
    }

    /// What a choice means. Stored as a string so new kinds can be added without a migration.
    public enum Choice: Equatable {
        /// The user's file in the Character folder, or the built-in sound when there is none.
        case standard
        case none
        case system(String)

        public init(_ stored: String?) {
            switch stored {
            case "none": self = .none
            case let s? where s.hasPrefix("system:"): self = .system(String(s.dropFirst("system:".count)))
            default: self = .standard
            }
        }

        public var stored: String? {
            switch self {
            case .standard: return nil
            case .none: return "none"
            case .system(let name): return "system:\(name)"
            }
        }
    }

    public func choice(in settings: AppSettings) -> Choice {
        Choice(settings.soundChoices[rawValue])
    }

    /// The user's own file for this effect: `<name>.mp3` / .m4a / .wav / .aiff / .caf in the Character folder.
    public var customFile: URL? {
        Self.extensions
            .map { AppPaths.characterDirectory.appendingPathComponent("\(rawValue).\($0)") }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// The file to play, or nil for silence (or, for the knock, the built-in synthesized knock).
    public func url(in settings: AppSettings) -> URL? {
        switch choice(in: settings) {
        case .standard: return customFile
        case .none: return nil
        case .system(let name): return Self.systemSound(name)
        }
    }

    /// Copies `source` into the Character folder as this effect's file, replacing any earlier one.
    public func install(_ source: URL) throws {
        try removeCustomFile()
        let dir = AppPaths.characterDirectory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let ext = source.pathExtension.lowercased()
        try FileManager.default.copyItem(at: source, to: dir.appendingPathComponent("\(rawValue).\(ext.isEmpty ? "mp3" : ext)"))
    }

    public func removeCustomFile() throws {
        while let file = customFile { try FileManager.default.removeItem(at: file) }
    }

    static let extensions = ["mp3", "m4a", "wav", "aiff", "aif", "caf"]
    static let systemSoundsDirectory = URL(fileURLWithPath: "/System/Library/Sounds")

    /// The sounds that ship with macOS (Glass, Hero, Pop…), by name.
    public static var systemSounds: [String] {
        let files = (try? FileManager.default.contentsOfDirectory(at: systemSoundsDirectory, includingPropertiesForKeys: nil)) ?? []
        return files.filter { extensions.contains($0.pathExtension.lowercased()) }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    public static func systemSound(_ name: String) -> URL? {
        extensions.map { systemSoundsDirectory.appendingPathComponent("\(name).\($0)") }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
