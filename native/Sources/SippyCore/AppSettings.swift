import Foundation

/// Which screen edge the character walks in from.
public enum EntrySide: String, Codable, CaseIterable {
    case left
    case right
}

/// Whether the character walks along the bottom of the screen or just under the menu bar.
public enum VerticalPosition: String, Codable, CaseIterable {
    case bottom
    case top
}

public enum TrackingMode: String, Codable, CaseIterable {
    case glasses
    case bottle
}

public struct AppSettings: Codable, Equatable {
    public var intervalMinutes: Int = 45
    public var snoozeMinutes: Int = 10
    public var dailyGoal: Int = 8
    public var volume: Double = 0.6
    public var muted: Bool = false
    public var musicPaths: [String] = []
    /// Minutes the character waits for an answer before snoozing on its own.
    public var autoSnoozeMinutes: Int = 3
    /// Glasses: goal is `dailyGoal` glasses of `glassML`. Bottle: goal is `dailyGoalML` sipped from a `bottleML` bottle.
    public var trackingMode: TrackingMode = .glasses
    public var glassML: Int = 250
    public var bottleML: Int = 1000
    public var dailyGoalML: Int = 2500
    public var entrySide: EntrySide = .left
    public var verticalPosition: VerticalPosition = .bottom
    /// Only remind between these times (minutes after midnight) when enabled.
    public var activeHoursEnabled = false
    public var activeFromMinutes = 9 * 60
    public var activeToMinutes = 18 * 60

    public init() {}

    public var activeHours: ActiveHours? {
        activeHoursEnabled ? ActiveHours(from: activeFromMinutes, to: activeToMinutes) : nil
    }

    public var goalML: Int {
        trackingMode == .glasses ? dailyGoal * glassML : dailyGoalML
    }

    /// Keeps every numeric setting in a sane range so a bad value can't cause a reminder storm.
    public func clamped() -> AppSettings {
        var s = self
        s.intervalMinutes = min(max(s.intervalMinutes, 1), 24 * 60)
        s.snoozeMinutes = min(max(s.snoozeMinutes, 1), 24 * 60)
        s.dailyGoal = min(max(s.dailyGoal, 1), 50)
        s.volume = min(max(s.volume, 0), 1)
        s.autoSnoozeMinutes = min(max(s.autoSnoozeMinutes, 1), 60)
        s.glassML = min(max(s.glassML, 50), 1000)
        s.bottleML = min(max(s.bottleML, 100), 3000)
        s.dailyGoalML = min(max(s.dailyGoalML, 250), 10000)
        s.activeFromMinutes = min(max(s.activeFromMinutes, 0), 24 * 60 - 1)
        s.activeToMinutes = min(max(s.activeToMinutes, 0), 24 * 60 - 1)
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
        trackingMode = try c.decodeIfPresent(TrackingMode.self, forKey: .trackingMode) ?? d.trackingMode
        glassML = try c.decodeIfPresent(Int.self, forKey: .glassML) ?? d.glassML
        bottleML = try c.decodeIfPresent(Int.self, forKey: .bottleML) ?? d.bottleML
        dailyGoalML = try c.decodeIfPresent(Int.self, forKey: .dailyGoalML) ?? d.dailyGoalML
        entrySide = try c.decodeIfPresent(EntrySide.self, forKey: .entrySide) ?? d.entrySide
        verticalPosition = try c.decodeIfPresent(VerticalPosition.self, forKey: .verticalPosition) ?? d.verticalPosition
        activeHoursEnabled = try c.decodeIfPresent(Bool.self, forKey: .activeHoursEnabled) ?? d.activeHoursEnabled
        activeFromMinutes = try c.decodeIfPresent(Int.self, forKey: .activeFromMinutes) ?? d.activeFromMinutes
        activeToMinutes = try c.decodeIfPresent(Int.self, forKey: .activeToMinutes) ?? d.activeToMinutes
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
