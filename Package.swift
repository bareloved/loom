// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Loom",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Loom",
            path: "Loom",
            exclude: ["Info.plist", "Loom.entitlements"],
            resources: [
                .copy("Resources/default-categories.json"),
                .copy("Resources/AppIcon.appiconset"),
                .copy("Resources/AppIcon.icns")
            ]
        ),
        .testTarget(
            name: "LoomTests",
            dependencies: ["Loom"],
            path: "LoomTests"
        )
    ]
)
