// swift-tools-version: 6.0
import PackageDescription

// VaultCore holds every piece of logic that does not need Apple frameworks:
// the classifier, the front matter parser, the Claude export reader, the GitHub
// diff and file naming. Foundation only (plus swift-crypto), so `swift test`
// also works on Linux.
//
// No `platforms:` block on purpose. Declaring .iOS(.v27) would stop the manifest
// from even parsing on an older Swift toolchain on Linux. The app target sets the
// real deployment target, and nothing here depends on a recent iOS version.
let package = Package(
    name: "VaultCore",
    products: [
        .library(name: "VaultCore", targets: ["VaultCore"])
    ],
    dependencies: [
        // SHA-256 for de-duplication. On Apple platforms it forwards to CryptoKit,
        // on Linux it ships its own implementation. 5.x needs Swift 6.2; the range
        // lets an older local toolchain fall back to 4.x.
        .package(url: "https://github.com/apple/swift-crypto.git", "4.0.0" ..< "6.0.0")
    ],
    targets: [
        .target(
            name: "VaultCore",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto")
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "VaultCoreTests",
            dependencies: ["VaultCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
