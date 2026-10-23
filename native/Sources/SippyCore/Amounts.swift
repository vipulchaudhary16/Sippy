import Foundation

/// One way to answer "how much did you drink?".
public struct DrinkOption: Equatable, Identifiable {
    public let label: String
    public let ml: Int
    public var id: String { label }

    public init(label: String, ml: Int) {
        self.label = label
        self.ml = ml
    }
}

/// Turns millilitres into what the user thinks in: glasses, or litres for bottle drinkers.
public struct Amounts {
    public let settings: AppSettings

    public init(_ settings: AppSettings) {
        self.settings = settings.clamped()
    }

    /// Value in display units (glasses or litres), for charts and averages.
    public func value(_ ml: Int) -> Double {
        switch settings.trackingMode {
        case .glasses: return Double(ml) / Double(settings.glassML)
        case .bottle: return Double(ml) / 1000
        }
    }

    public var unitName: String {
        settings.trackingMode == .glasses ? "glasses" : "litres"
    }

    /// "3 glasses", "1 glass", "1.5 glasses" / "1.2 L".
    public func describe(_ ml: Int) -> String {
        switch settings.trackingMode {
        case .glasses:
            let n = value(ml)
            return "\(format(n)) \(n == 1 ? "glass" : "glasses")"
        case .bottle:
            return "\(format(value(ml))) L"
        }
    }

    /// "3 of 8 glasses" / "1.2 of 2.5 L".
    public func progress(_ ml: Int) -> String {
        switch settings.trackingMode {
        case .glasses: return "\(format(value(ml))) of \(settings.dailyGoal) glasses"
        case .bottle: return "\(format(value(ml))) of \(format(value(settings.goalML))) L"
        }
    }

    /// Bottle mode: the goal in bottles, e.g. "2½ bottles".
    public var goalInBottles: String {
        let bottles = Double(settings.dailyGoalML) / Double(settings.bottleML)
        let whole = Int(bottles)
        let frac = bottles - Double(whole)
        let suffix: String
        switch frac {
        case ..<0.125: suffix = ""
        case ..<0.375: suffix = "¼"
        case ..<0.625: suffix = "½"
        case ..<0.875: suffix = "¾"
        default: return whole == 0 ? "1 bottle" : "\(whole + 1) bottles"
        }
        if whole == 0 { return "\(suffix) bottle" }
        return "\(whole)\(suffix) \(whole == 1 && suffix.isEmpty ? "bottle" : "bottles")"
    }

    /// Glasses: one glass. Bottle: sips, a quarter, half, or the whole thing.
    public var drinkOptions: [DrinkOption] {
        switch settings.trackingMode {
        case .glasses:
            return [DrinkOption(label: "Yes, I drank!", ml: settings.glassML)]
        case .bottle:
            let b = settings.bottleML
            return [
                DrinkOption(label: "A few sips", ml: max(50, b / 10)),
                DrinkOption(label: "¼ bottle", ml: b / 4),
                DrinkOption(label: "½ bottle", ml: b / 2),
                DrinkOption(label: "Whole bottle", ml: b),
            ]
        }
    }

    /// What "Log a glass" in the menu and dashboard adds.
    public var quickLog: DrinkOption {
        settings.trackingMode == .glasses
            ? DrinkOption(label: "Log a Glass", ml: settings.glassML)
            : DrinkOption(label: "Log ¼ Bottle", ml: settings.bottleML / 4)
    }

    /// Amount names used by `sippy://log?amount=…` and the Spotlight actions:
    /// glass, sips, quarter, half, bottle, or a plain number of millilitres.
    public func ml(forAmount name: String) -> Int? {
        let b = settings.bottleML
        switch name.lowercased() {
        case "glass": return settings.glassML
        case "sips", "sip": return max(50, b / 10)
        case "quarter": return b / 4
        case "half": return b / 2
        case "bottle", "whole": return b
        default:
            guard let ml = Int(name), ml > 0 else { return nil }
            return min(ml, 5000)
        }
    }

    /// The Spotlight actions to offer for the current mode: (amount name, title).
    public var spotlightActions: [(amount: String, title: String)] {
        switch settings.trackingMode {
        case .glasses:
            return [("glass", "Log Water – Glass")]
        case .bottle:
            return [("sips", "Log Water – A Few Sips"), ("quarter", "Log Water – ¼ Bottle"),
                    ("half", "Log Water – ½ Bottle"), ("bottle", "Log Water – Whole Bottle")]
        }
    }

    /// A display-unit value as text: litres keep two decimals so 0.25 + 2.25 still reads as 2.5,
    /// glasses keep one. Trailing zeros are dropped (2.50 -> "2.5", 3.0 -> "3").
    public func format(_ x: Double) -> String {
        let places = settings.trackingMode == .bottle ? 2 : 1
        var text = String(format: "%.\(places)f", x)
        while text.contains("."), text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text == "-0" ? "0" : text
    }
}
