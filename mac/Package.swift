// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "StenoDrop",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "StenoDrop",
            path: "Sources/StenoDrop"
        )
    ]
)
