// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Sippy",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "SippyCore"),
        // Turns any video of a character into a transparent clip (used by Settings and the CLI below).
        .target(name: "SippyVideo"),
        .executableTarget(name: "Sippy", dependencies: ["SippyCore", "SippyVideo"]),
        .executableTarget(name: "make-video-character", dependencies: ["SippyVideo"]),
        // Command Line Tools can't load XCTest/Swift Testing, so core logic is
        // checked by a plain executable: `swift run SippyChecks`.
        .executableTarget(name: "SippyChecks", dependencies: ["SippyCore"]),
    ]
)
