// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Vertano",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "Vertano",
            path: "Sources/Vertano"
        ),
        .testTarget(
            name: "VertanoTests",
            dependencies: ["Vertano"],
            path: "Tests/VertanoTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
