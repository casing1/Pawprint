// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Pawprint",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        // The domain: models, statistics, storage, and the policy deciding what any of it means.
        // No AppKit, no SwiftUI, nothing needing a running application — which is what makes it
        // testable on its own.
        //
        // Symbols crossing into the app target are marked `package`, not `public`: this is a seam
        // between two targets of one package, not an API anyone outside consumes.
        //
        // The language packs stay declared on the app target. `LocalizationManager` searches
        // `Bundle.main` rather than a generated bundle accessor (deliberately — see its comment),
        // so which target declares them makes no difference at runtime, and leaving them put keeps
        // `build_app.sh` packaging unchanged.
        .target(
            name: "PawprintCore",
            path: "Sources/PawprintCore",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        // The application: AppKit and SwiftUI, the system monitors, and the wiring between them
        // and the domain above.
        .executableTarget(
            name: "Pawprint",
            dependencies: ["PawprintCore"],
            path: "Sources/Pawprint",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .testTarget(
            name: "PawprintTests",
            dependencies: ["PawprintCore", "Pawprint"],
            path: "Tests/PawprintTests"
        )
    ]
)
