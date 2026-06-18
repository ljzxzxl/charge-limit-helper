// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "charge-limit-helper",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "ChargeLimitCore", targets: ["ChargeLimitCore"]),
        .executable(name: "charge-limit-helperd", targets: ["ChargeLimitHelper"]),
        .executable(name: "charge-limit", targets: ["ChargeLimitCLI"]),
        .executable(name: "charge-limit-monitor", targets: ["ChargeLimitMonitor"]),
        .executable(name: "charge-limit-menubar", targets: ["ChargeLimitMenuBar"])
    ],
    targets: [
        .target(
            name: "ChargeLimitCore",
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        ),
        .executableTarget(
            name: "ChargeLimitHelper",
            dependencies: ["ChargeLimitCore"]
        ),
        .executableTarget(
            name: "ChargeLimitCLI",
            dependencies: ["ChargeLimitCore"],
            path: "Sources/charge-limit"
        ),
        .executableTarget(
            name: "ChargeLimitMonitor",
            dependencies: ["ChargeLimitCore"],
            path: "Sources/charge-limit-monitor"
        ),
        .executableTarget(
            name: "ChargeLimitMenuBar",
            dependencies: ["ChargeLimitCore"],
            path: "Sources/charge-limit-menubar",
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        )
    ]
)
