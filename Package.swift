// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Pawprint",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Pawprint",
            path: "Sources/Pawprint",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
