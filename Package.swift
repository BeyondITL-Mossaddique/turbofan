// swift-tools-version:5.10
import PackageDescription

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
        .executableTarget(name: "TurboFanApp", dependencies: ["TurboCore"]),
        .executableTarget(name: "turbofan", dependencies: ["TurboCore"]),
        .executableTarget(name: "turbofand", dependencies: ["TurboCore"]),
    ]
)
