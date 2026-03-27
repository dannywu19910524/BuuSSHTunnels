// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Tunnel",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Tunnel",
            path: "Sources/Tunnel"
        ),
        .testTarget(
            name: "TunnelTests",
            dependencies: ["Tunnel"],
            path: "Tests/TunnelTests"
        )
    ]
)
