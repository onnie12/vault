// swift-tools-version: 6.0
import PackageDescription

// VaultCore holds every piece of logic that does not need Apple frameworks:
// the classifier, the front matter parser, the Claude export reader, the GitHub
// diff and file naming. Foundation only, so `swift test` also works on Linux.
//
// No `platforms:` block on purpose. Declaring .iOS(.v27) would stop the manifest
// from even parsing on an older Swift toolchain on Linux. The app target sets the
// real deployment target, and nothing here depends on a recent iOS version.
let package = Package(
    name: "VaultCore",
    products: [
        .library(name: "VaultCore", targets: ["VaultCore"])
    ],
    targets: [
        .target(
            name: "VaultCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "VaultCoreTests",
            dependencies: ["VaultCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
