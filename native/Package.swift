// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Sippy",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "SippyCore"),
        .executableTarget(name: "Sippy", dependencies: ["SippyCore"]),
        // Command Line Tools can't load XCTest/Swift Testing, so core logic is
        // checked by a plain executable: `swift run SippyChecks`.
        .executableTarget(name: "SippyChecks", dependencies: ["SippyCore"]),
    ]
)
