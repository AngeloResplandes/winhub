// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WinHub",
    defaultLocalization: "pt",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "WinHub", targets: ["WinHub"]),
        .library(name: "WinHubCore", targets: ["WinHubCore"]),
        .library(name: "WinHubRuntime", targets: ["WinHubRuntime"]),
    ],
    targets: [
        .target(name: "WinHubCore"),
        .target(name: "WinHubRuntime"),
        .executableTarget(
            name: "WinHub",
            dependencies: ["WinHubCore", "WinHubRuntime"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "WinHubCoreTests", dependencies: ["WinHubCore"]),
        .testTarget(name: "WinHubRuntimeTests", dependencies: ["WinHubRuntime"]),
    ]
)
