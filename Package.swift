// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacBreathe",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "MacBreathe", targets: ["MacBreathe"]),
        // Library product so Xcode makes a scheme for it: SwiftUI previews do not run in executable targets.
        .library(name: "MacBreatheUI", targets: ["MacBreatheUI"]),
    ],
    targets: [
        .target(name: "MacBreatheCore"),
        .target(name: "MacBreatheUI", dependencies: ["MacBreatheCore"]),
        .executableTarget(name: "MacBreathe", dependencies: ["MacBreatheUI"]),
        .testTarget(name: "MacBreatheCoreTests", dependencies: ["MacBreatheCore"]),
    ]
)
