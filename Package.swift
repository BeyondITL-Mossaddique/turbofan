// swift-tools-version:5.10
import Foundation
import PackageDescription

// TURBOFAN_PRO=1 swift build ... compiles the Pro edition flag into the app.
let proSettings: [SwiftSetting] = ProcessInfo.processInfo.environment["TURBOFAN_PRO"] == "1" ? [.define("TURBOFAN_PRO")] : []

let package = Package(
    name: "TurboFan",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TurboFanApp", targets: ["TurboFanApp"]),
        .executable(name: "turbofan", targets: ["turbofan"]),
        .executable(name: "turbofand", targets: ["turbofand"]),
    ],
    targets: [
        .target(name: "TurboCore", linkerSettings: [.linkedFramework("IOKit")]),
        .executableTarget(name: "TurboFanApp", dependencies: ["TurboCore"], swiftSettings: proSettings),
        .executableTarget(name: "turbofan", dependencies: ["TurboCore"]),
        .executableTarget(name: "turbofand", dependencies: ["TurboCore"]),
    ]
)
