// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NtfyKit",
    platforms: [.iOS(.v26), .watchOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "NtfyKit", targets: ["NtfyKit"]),
    ],
    targets: [
        .target(name: "NtfyKit", resources: [.process("Resources")]),
        .testTarget(name: "NtfyKitTests", dependencies: ["NtfyKit"]),
    ]
)
