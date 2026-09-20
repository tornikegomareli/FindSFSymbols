// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "FindSFSymbols",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.8.0"),
    ],
    targets: [
        .executableTarget(
            name: "FindSFSymbols",
            dependencies: ["SymbolSearch", .product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/FindSFSymbols",
            // package_app.sh copies Resources into the app bundle. A SwiftPM resource bundle is not used,
            // because its generated accessor writes the absolute build path into the binary.
            exclude: ["Resources"]),
        .target(
            name: "SymbolSearch",
            path: "Sources/SymbolSearch"),
        .testTarget(
            name: "SymbolSearchTests",
            dependencies: ["SymbolSearch"],
            path: "Tests/SymbolSearchTests"),
        .testTarget(
            name: "FindSFSymbolsTests",
            dependencies: ["FindSFSymbols"],
            path: "Tests/FindSFSymbolsTests"),
    ]
)
