import Foundation

public struct AppSettings: Codable, Equatable {
    public var intervalMinutes: Int = 45
    public var snoozeMinutes: Int = 10
    public var dailyGoal: Int = 8
    public var volume: Double = 0.6
    public var muted: Bool = false
    public var musicPaths: [String] = []
    /// Minutes the character waits for an answer before snoozing on its own.
    public var autoSnoozeMinutes: Int = 3

    public init() {}

    /// Keeps every numeric setting in a sane range so a bad value can't cause a reminder storm.
    public func clamped() -> AppSettings {
        var s = self
        s.intervalMinutes = min(max(s.intervalMinutes, 1), 24 * 60)
        s.snoozeMinutes = min(max(s.snoozeMinutes, 1), 24 * 60)
        s.dailyGoal = min(max(s.dailyGoal, 1), 50)
        s.volume = min(max(s.volume, 0), 1)
        s.autoSnoozeMinutes = min(max(s.autoSnoozeMinutes, 1), 60)
        return s
    }

    // Decode field-by-field so settings saved by an older build still load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        intervalMinutes = try c.decodeIfPresent(Int.self, forKey: .intervalMinutes) ?? d.intervalMinutes
        snoozeMinutes = try c.decodeIfPresent(Int.self, forKey: .snoozeMinutes) ?? d.snoozeMinutes
        dailyGoal = try c.decodeIfPresent(Int.self, forKey: .dailyGoal) ?? d.dailyGoal
        volume = try c.decodeIfPresent(Double.self, forKey: .volume) ?? d.volume
        muted = try c.decodeIfPresent(Bool.self, forKey: .muted) ?? d.muted
        musicPaths = try c.decodeIfPresent([String].self, forKey: .musicPaths) ?? d.musicPaths
        autoSnoozeMinutes = try c.decodeIfPresent(Int.self, forKey: .autoSnoozeMinutes) ?? d.autoSnoozeMinutes
    }
}

public final class SettingsStore {
    private let defaults: UserDefaults
    private let key = "sippy.settings.v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> AppSettings {
        guard let data = defaults.data(forKey: key),
              let s = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return s.clamped()
    }

    public func save(_ settings: AppSettings) {
        if let data = try? JSONEncoder().encode(settings.clamped()) {
            defaults.set(data, forKey: key)
        }
    }
}
